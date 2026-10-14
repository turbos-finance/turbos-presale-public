module presale::claim {
    use std::vector;

    use sui::bag::{Self, Bag};
    use sui::clock::{Self, Clock};
    use sui::coin::{Self, Coin};
    use sui::event;
    use sui::object::{Self, UID, ID};
    use sui::transfer::{public_transfer, public_share_object};
    use sui::tx_context::{Self, TxContext};

    #[test_only]
    use sui::sui::SUI;
    #[test_only]
    use sui::test_scenario::{Self, next_tx, end};
    #[test_only]
    use sui::test_utils;

    const FEE_RATE_SCALE: u64 = 1_000_000;

    const E_OWNER_ONLY: u64 = 1000;
    const E_EMERGENCY_ON: u64 = 1001;
    const E_NOT_NEED_CLAIM: u64 = 1002;
    const E_ARGS_NOT_MATCH: u64 = 1003;
    const E_NOT_STARTED: u64 = 1004;
    const E_INVALID_TIME: u64 = 1005;
    const E_NOT_REVOCABLE: u64 = 1006;
    const E_INVALID_PERCENTAGE: u64 = 1007;
    const E_INVALID_AMOUNT: u64 = 1008;
    const E_INVALID_SLICE_PERIOD: u64 = 1009;


    struct ManageCap<phantom T> has key, store {
        id: UID,
        claim_id: ID,
    }

    struct ClaimInfo has copy, store, drop {
        total_amount: u64,
        claimed_amount: u64,
        revoked: bool,
    }

    struct Claim<phantom T> has key, store {
        id: UID,
        emergency: bool,
        // start time in seconds
        start_time: u64,
        end_time: u64,
        balance: Coin<T>,
        members: Bag,
        // cliff time of the vesting start in ms since the UNIX epoch
        // if there is no cliff period, then cliff = start_time
        cliff: u64,
        // duration of the vesting period in seconds
        duration: u64,
        // duration of a slice period for the vesting in seconds
        slice_period_seconds: u64,
        // percentage released on claim start
        init_release_percentage: u64,
        // whether or not the vesting is revocable
        revocable: bool,
    }

    struct ClaimEvent has copy, drop {
        address: address,
        amount: u64,
    }

    struct ChangeStartTimeEvent has copy, drop {
        claim_id: ID,
        start_time: u64,
    }

    struct ChangeEndTimeEvent has copy, drop {
        claim_id: ID,
        end_time: u64,
    }

    struct ChangeCliffTimeEvent has copy, drop {
        claim_id: ID,
        cliff_time: u64,
    }

    struct ChangeClaimInfoEvent has copy, drop {
        claim_id: ID,
        address: address,
        total_amount: u64,
        claimed_amount: u64,
        revoked: bool,
    }

    struct RevokedEvent has copy, drop {
        claim_id: ID,
        address: address,
        revoke: bool,
    }

    struct AddWaitClaimListEvent has copy, drop {
        claim_id: ID,
        list: vector<address>,
        amounts: vector<u64>,
    }

    struct RecoveryRevokedEvent has copy, drop {
        claim_id: ID,
        address: address,
        revoke: bool,
    }

    public entry fun create_claim<T>(
        c: Coin<T>, 
        start_time: u64, 
        end_time: u64, 
        cliff: u64,
        duration: u64,
        slice_period_seconds: u64,
        init_release_percentage: u64,
        revocable: bool,
        ctx: &mut TxContext
    ) {
        let (claim, manage_cap) = create_claim_with_return(
            c,
            start_time,
            end_time,
            cliff,
            duration,
            slice_period_seconds,
            init_release_percentage,
            revocable,
            ctx,
        );
        public_transfer(manage_cap, tx_context::sender(ctx));
        public_share_object(claim);
    }

    public fun create_claim_with_return<T>(
        c: Coin<T>, 
        start_time: u64,
        end_time: u64,
        cliff: u64,
        duration: u64,
        slice_period_seconds: u64,
        init_release_percentage: u64,
        revocable: bool,
        ctx: &mut TxContext
    ): (Claim<T>, ManageCap<T>) {
        assert!(end_time > start_time + duration, E_INVALID_TIME);
        assert!(cliff >= start_time, E_INVALID_TIME);
        assert!(slice_period_seconds >= 0, E_INVALID_SLICE_PERIOD);
        assert!(init_release_percentage <= FEE_RATE_SCALE, E_INVALID_PERCENTAGE);
        let claim = Claim {
            id: object::new(ctx),
            emergency: false,
            start_time,
            end_time,
            balance: c,
            cliff: cliff,
            duration: duration,
            slice_period_seconds: slice_period_seconds,
            init_release_percentage: init_release_percentage,
            revocable: revocable,
            members: bag::new(ctx),
        };
        let manage_cap = ManageCap<T> {
            id: object::new(ctx),
            claim_id: object::id(&claim),
        };
        (claim, manage_cap)
    }

    public entry fun claim<T>(c: &mut Claim<T>, clock: &Clock, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);
        let claim_coin = claim_with_return(c, clock, ctx);
        public_transfer(claim_coin, sender);
    }

    public fun claim_with_return<T>(claim: &mut Claim<T>, clock: &Clock, ctx: &mut TxContext): Coin<T> {
        assert!(!claim.emergency, E_EMERGENCY_ON);
        let sender = tx_context::sender(ctx);
        assert!(bag::contains(&claim.members, sender), E_NOT_NEED_CLAIM);

        let current_time = clock::timestamp_ms(clock) / 1000;
        assert!(current_time >= claim.start_time && current_time <= claim.end_time, E_NOT_STARTED);
        
        let released_amount = compute_released_amount(claim, sender, clock);
        let claim_info = bag::borrow_mut<address, ClaimInfo>(&mut claim.members, sender);
        assert!(released_amount <= claim_info.total_amount, E_INVALID_AMOUNT);
        
        //amount need claim
        let amount = released_amount - claim_info.claimed_amount;
        assert!(amount > 0, E_NOT_NEED_CLAIM);

        let claim_coin = coin::split(&mut claim.balance, amount, ctx);
        claim_info.claimed_amount = released_amount;
        event::emit(ClaimEvent {
            address: sender,
            amount: amount,
        });

        claim_coin
    }

    public fun compute_released_amount<T>(claim: &Claim<T>, beneficiary: address, clock: &Clock): u64 {
        let current_time = clock::timestamp_ms(clock) / 1000;
        let claim_info = bag::borrow<address, ClaimInfo>(&claim.members, beneficiary);
        if (current_time < claim.start_time || claim_info.revoked == true) {
            return 0
        };
        
        let released_amount = 0;
        let init_release_amount = 0;
        if (current_time >= claim.start_time && claim.init_release_percentage > 0) {
            init_release_amount = mul_div_ceil(claim_info.total_amount, claim.init_release_percentage, FEE_RATE_SCALE);
        };
        if (current_time >= claim.cliff + claim.duration) {
            released_amount =  claim_info.total_amount - init_release_amount;
        } else if (current_time >= claim.cliff) {
            let time_from_start = current_time - claim.cliff;
            let vested_slice_periods = time_from_start / claim.slice_period_seconds;
            let vested_seconds = vested_slice_periods * claim.slice_period_seconds;
            released_amount = mul_div_ceil(claim_info.total_amount - init_release_amount, vested_seconds, claim.duration);
        };

        released_amount + init_release_amount
    }

    public entry fun add_wait_claim_list<T>(
        claim: &mut Claim<T>,
        adm: &ManageCap<T>,
        list: vector<address>,
        amounts: vector<u64>,
    ) {
        assert!(object::id(claim) == adm.claim_id, E_OWNER_ONLY);
        let length = vector::length(&list);
        assert!(length == vector::length(&amounts), E_ARGS_NOT_MATCH);

        let i = 0;
        while (i < length) {
            let ads = vector::pop_back(&mut list);
            let amount = vector::pop_back(&mut amounts);
            if (bag::contains(&claim.members, ads)) {
                let claim_info = bag::borrow_mut<address,ClaimInfo>(&mut claim.members, ads);
                claim_info.total_amount = amount;
            } else {
                bag::add(&mut claim.members, ads, ClaimInfo {
                    total_amount: amount,
                    claimed_amount: 0,
                    revoked: false
                });
            };
            i = i + 1;
        };

        let event = AddWaitClaimListEvent {
            claim_id: adm.claim_id,
            list: list,
            amounts: amounts
        };
        event::emit(event)
    }

    public fun check_claim_info<T>(claim: &Claim<T>, addr: address, clock: &Clock): (u64, u64, u64) {
        if (!bag::contains(&claim.members, addr)) {
            return (0, 0, 0)
        };
        let claim_info = bag::borrow<address,ClaimInfo>(&claim.members, addr);
        let released_amount = compute_released_amount(claim, addr, clock);
        (claim_info.total_amount, claim_info.claimed_amount, released_amount - claim_info.claimed_amount)
    }

    public entry fun change_start_time<T>(
        claim: &mut Claim<T>,
        manage: &ManageCap<T>,
        start_time:u64,
    ) {
        assert!(object::id(claim) == manage.claim_id, E_OWNER_ONLY);
        assert!(claim.end_time > start_time, E_INVALID_TIME);
        claim.start_time = start_time;

        event::emit(ChangeStartTimeEvent {
            claim_id: object::id(claim),
            start_time,
        })
    }

    public entry fun change_end_time<T>(
        claim: &mut Claim<T>,
        manage: &ManageCap<T>,
        end_time: u64
    ) {
        assert!(object::id(claim) == manage.claim_id, E_OWNER_ONLY);
        assert!(end_time > claim.start_time, E_INVALID_TIME);
        claim.end_time = end_time;
        event::emit(ChangeEndTimeEvent {
            claim_id: object::id(claim),
            end_time,
        })
    }

    public entry fun change_cliff_time<T>(
        claim: &mut Claim<T>,
        manage: &ManageCap<T>,
        cliff_time: u64
    ) {
        assert!(object::id(claim) == manage.claim_id, E_OWNER_ONLY);
        assert!(cliff_time >= claim.start_time, E_INVALID_TIME);
        claim.cliff = cliff_time;
        event::emit(ChangeCliffTimeEvent {
            claim_id: object::id(claim),
            cliff_time:  cliff_time,
        })
    }


    public entry fun change_claim_info<T>(
        claim: &mut Claim<T>,
        manage: &ManageCap<T>,
        beneficiary: address,
        total_amount: u64,
        claimed_amount: u64,
        revoked: bool,
    ) {
        assert!(object::id(claim) == manage.claim_id, E_OWNER_ONLY);
        let claim_info = bag::borrow_mut<address, ClaimInfo>(&mut claim.members, beneficiary);
        claim_info.revoked = revoked;
        claim_info.total_amount = total_amount;
        claim_info.claimed_amount = claimed_amount;

        event::emit(ChangeClaimInfoEvent {
            claim_id: object::id(claim),
            address: beneficiary,
            revoked: revoked,
            total_amount: total_amount,
            claimed_amount: claimed_amount,
        })
    }


    public entry fun revoke<T>(
        claim: &mut Claim<T>,
        manage: &ManageCap<T>,
        beneficiary: address,
    ) {
        assert!(object::id(claim) == manage.claim_id, E_OWNER_ONLY);
        assert!(claim.revocable, E_NOT_REVOCABLE);
        let claim_info = bag::borrow_mut<address, ClaimInfo>(&mut claim.members, beneficiary);
        assert!(claim_info.revoked == false, E_NOT_REVOCABLE);
        claim_info.revoked = true;

        event::emit(RevokedEvent {
            claim_id: object::id(claim),
            address: beneficiary,
            revoke: true,
        })
    }

    public entry fun recovery_revoke<T>(
        claim: &mut Claim<T>,
        manage: &ManageCap<T>,
        beneficiary: address,
    ) {
        assert!(object::id(claim) == manage.claim_id, E_OWNER_ONLY);
        assert!(claim.revocable, E_NOT_REVOCABLE);
        let claim_info = bag::borrow_mut<address, ClaimInfo>(&mut claim.members, beneficiary);
        claim_info.revoked = false;

        event::emit(RecoveryRevokedEvent {
            claim_id: object::id(claim),
            address: beneficiary,
            revoke: false,
        })
    }

    public entry fun emergency_switch<T>(claim: &mut Claim<T>, adm: &ManageCap<T>) {
        assert!(object::id(claim) == adm.claim_id, E_OWNER_ONLY);
        claim.emergency = !claim.emergency
    }

    public entry fun emergency_withdraw<T>(claim: &mut Claim<T>, adm: &ManageCap<T>, recipitor: address, ctx: &mut TxContext) {
        assert!(object::id(claim) == adm.claim_id, E_OWNER_ONLY);
        let val = coin::value(&claim.balance);
        let balance = coin::split(&mut claim.balance, val, ctx);
        public_transfer(balance, recipitor);
    }

    public entry fun emergency_deposit<T>(claim: &mut Claim<T>, adm: &ManageCap<T>, paid: Coin<T>) {
        assert!(object::id(claim) == adm.claim_id, E_OWNER_ONLY);
        coin::join(&mut claim.balance, paid);
    }

    public fun mul_div_ceil(num1: u64, num2: u64, denom: u64): u64 {
        let r = (full_mul(num1, num2) + ((denom as u128) - 1)) / (denom as u128);
        (r as u64)
    }

    public fun full_mul(num1: u64, num2: u64): u128 {
        ((num1 as u128) * (num2 as u128))
    }

    #[test_only]
    const DECIMA: u64 = 1000000000;
    #[test_only]
    const START_TIMEL: u64 = 0;
    const END_TIME: u64 = 1000;

    #[test]
    fun test_init_claim() {
        let ctx = tx_context::dummy();
        let sender = tx_context::sender(&mut ctx);
        let scenario = test_scenario::begin(sender);

        let s = coin::mint_for_testing<SUI>(1000 * DECIMA, &mut ctx);
        let (claim, manage_cap) = create_claim_with_return(s, START_TIMEL, END_TIME, 10, 100, 10, 100_000,false, &mut ctx);
        assert!(claim.start_time == START_TIMEL, 1);
        assert!(claim.cliff == 10, 3);
        assert!(claim.duration == 100, 4);
        assert!(claim.slice_period_seconds == 10, 4);
        assert!(claim.init_release_percentage == 100_000, 5);
        assert!(claim.revocable == false, 6);


        public_transfer(manage_cap, sender);
        public_share_object(claim);
        end(scenario);
    }

    #[test]
    fun test_claim_with_cliff() {
        let ctx = tx_context::dummy();
        let sender = tx_context::sender(&mut ctx);
        let scenario = test_scenario::begin(sender);

        
        let s = coin::mint_for_testing<SUI>(1000 * DECIMA, &mut ctx);
        let cliff = 10; //10s
        let duration = 100; //100s
        let slice_period_seconds = 10; //10s
        let init_release_percentage = 200_000; //20%
        let (claim, manage_cap) = create_claim_with_return(
            s, 
            START_TIMEL,
            END_TIME,
            cliff, 
            duration, 
            slice_period_seconds, 
            init_release_percentage,
            false, 
            &mut ctx
        );
        let clock = clock::create_for_testing(&mut ctx);

        let list = vector::empty<address>();
        let amounts = vector::empty<u64>();
        vector::push_back(&mut list, sender);
        vector::push_back(&mut amounts, 10 * DECIMA);

        add_wait_claim_list(&mut claim, &manage_cap, list, amounts);
        let c = claim_with_return(&mut claim, &clock, &mut ctx);
        //init percentage 20%
        assert!(coin::value(&c) == 2 * DECIMA, 1);

        //forwarding 10s, cliff off
        clock::increment_for_testing(&mut clock, 10000);
        let released = compute_released_amount(&mut claim, sender, &clock);
        assert!(released == 2 * DECIMA, 1);

        //forwarding 10s, arrive at the first release
        clock::increment_for_testing(&mut clock, 10000);
        let released = compute_released_amount(&mut claim, sender, &clock);
        assert!(released == 28 * DECIMA / 10, 1);

        //forwarding 90s, claim all
        clock::increment_for_testing(&mut clock, 90000);
        let c2 = claim_with_return(&mut claim, &clock, &mut ctx);
        assert!(coin::value(&c2) == 8 * DECIMA, 1);

        //forwarding 10s, no claim
        clock::increment_for_testing(&mut clock, 10000);
        let released = compute_released_amount(&mut claim, sender, &clock);
        assert!(released == 10 * DECIMA, 1);

        test_utils::destroy(c);
        test_utils::destroy(c2);
        test_utils::destroy(clock);
        public_transfer(manage_cap, sender);
        public_share_object(claim);
        end(scenario);
    }

    #[test]
    fun test_claim_no_cliff() {
        let ctx = tx_context::dummy();
        let sender = tx_context::sender(&mut ctx);
        let scenario = test_scenario::begin(sender);

        
        let s = coin::mint_for_testing<SUI>(1000 * DECIMA, &mut ctx);
        let cliff = START_TIMEL; //0s
        let duration = 100; //100s
        let slice_period_seconds = 10; //10s
        let init_release_percentage = 0; //0%
        let (claim, manage_cap) = create_claim_with_return(
            s, 
            START_TIMEL,
            END_TIME,
            cliff, 
            duration, 
            slice_period_seconds, 
            init_release_percentage,
            false, 
            &mut ctx
        );
        let clock = clock::create_for_testing(&mut ctx);

        let list = vector::empty<address>();
        let amounts = vector::empty<u64>();
        vector::push_back(&mut list, sender);
        vector::push_back(&mut amounts, 10 * DECIMA);

        add_wait_claim_list(&mut claim, &manage_cap, list, amounts);
    
        //forwarding 9s, but did not reach first release
        clock::increment_for_testing(&mut clock, 9000);
        let released = compute_released_amount(&mut claim, sender, &clock);
        assert!(released == 0, 1);

        //forwarding 1s, arrive at the first release
        clock::increment_for_testing(&mut clock, 1000);
        let c = claim_with_return(&mut claim, &clock, &mut ctx);
        assert!(coin::value(&c) == 1 * DECIMA, 1);

        //forwarding 90s, claim all
        clock::increment_for_testing(&mut clock, 90000);
        let c2 = claim_with_return(&mut claim, &clock, &mut ctx);
        assert!(coin::value(&c2) == 9 * DECIMA, 1);

        //forwarding 10s, no claim
        clock::increment_for_testing(&mut clock, 10000);
        let released = compute_released_amount(&mut claim, sender, &clock);
        assert!(released == 10 * DECIMA, 1);


        test_utils::destroy(c);
        test_utils::destroy(c2);
        test_utils::destroy(clock);
        public_transfer(manage_cap, sender);
        public_share_object(claim);
        end(scenario);
    }

    #[test]
    fun test_claim_no_cliff_first_release() {
        let ctx = tx_context::dummy();
        let sender = tx_context::sender(&mut ctx);
        let scenario = test_scenario::begin(sender);

        
        let s = coin::mint_for_testing<SUI>(1000 * DECIMA, &mut ctx);
        let cliff = START_TIMEL; //0s
        let duration = 90; //90s
        let slice_period_seconds = 9; //10s
        let init_release_percentage = 100_000; //10%
        let (claim, manage_cap) = create_claim_with_return(
            s, 
            START_TIMEL,
            END_TIME, 
            cliff, 
            duration, 
            slice_period_seconds, 
            init_release_percentage,
            false, 
            &mut ctx
        );
        let clock = clock::create_for_testing(&mut ctx);

        let list = vector::empty<address>();
        let amounts = vector::empty<u64>();
        vector::push_back(&mut list, sender);
        vector::push_back(&mut amounts, 100 * DECIMA);

        add_wait_claim_list(&mut claim, &manage_cap, list, amounts);

        //first release
        let c = claim_with_return(&mut claim, &clock, &mut ctx);
        assert!(coin::value(&c) == 10 * DECIMA, 1);
    
        //forwarding 8s, but did not reach second release
        clock::increment_for_testing(&mut clock, 8000);
        let released = compute_released_amount(&mut claim, sender, &clock);
        assert!(released == 10 * DECIMA, 1);

        //forwarding 1s, arrive at the second release
        clock::increment_for_testing(&mut clock, 1000);
        let c2 = claim_with_return(&mut claim, &clock, &mut ctx);
        assert!(coin::value(&c2) == 9 * DECIMA, 1);

        //forwarding 81s, claim all
        clock::increment_for_testing(&mut clock, 81000);
        let c3 = claim_with_return(&mut claim, &clock, &mut ctx);
        assert!(coin::value(&c3) == 81 * DECIMA, 1);

        //forwarding 10s, no claim
        clock::increment_for_testing(&mut clock, 10000);
        let released = compute_released_amount(&mut claim, sender, &clock);
        assert!(released == 100 * DECIMA, 1);


        test_utils::destroy(c);
        test_utils::destroy(c2);
        test_utils::destroy(c3);
        test_utils::destroy(clock);
        public_transfer(manage_cap, sender);
        public_share_object(claim);
        end(scenario);
    }

    #[test]
    fun test_claim_no_vesting() {
        let ctx = tx_context::dummy();
        let sender = tx_context::sender(&mut ctx);
        let scenario = test_scenario::begin(sender);

        
        let s = coin::mint_for_testing<SUI>(1000 * DECIMA, &mut ctx);
        let cliff = 0; //0s
        let duration = 0; //100s
        let slice_period_seconds = 0; //10s
        let init_release_percentage = 100; //0%
        let (claim, manage_cap) = create_claim_with_return(
            s, 
            1,  // start on 1s
            END_TIME,
            1, 
            duration, 
            slice_period_seconds, 
            init_release_percentage,
            false, 
            &mut ctx
        );
        let clock = clock::create_for_testing(&mut ctx);

        let list = vector::empty<address>();
        let amounts = vector::empty<u64>();
        vector::push_back(&mut list, sender);
        vector::push_back(&mut amounts, 10 * DECIMA);
        vector::push_back(&mut list, sender);
        vector::push_back(&mut amounts, 10 * DECIMA);

        add_wait_claim_list(&mut claim, &manage_cap, list, amounts);
    
        let released = compute_released_amount(&mut claim, sender, &clock);
        assert!(released == 0, 1);

        //forwarding 1s, arrive at the first release, release all
        clock::increment_for_testing(&mut clock, 1000);
        let c = claim_with_return(&mut claim, &clock, &mut ctx);
        assert!(coin::value(&c) == 10 * DECIMA, 1);

        //forwarding 10s, no claim
        clock::increment_for_testing(&mut clock, 10000);
        let released = compute_released_amount(&mut claim, sender, &clock);
        assert!(released == 10 * DECIMA, 1);


        test_utils::destroy(c);
        test_utils::destroy(clock);
        public_transfer(manage_cap, sender);
        public_share_object(claim);
        end(scenario);
    }
}

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

    const E_OWNER_ONLY: u64 = 1000;
    const E_EMERGENCY_ON: u64 = 1001;
    const E_NOT_NEED_CLAIM: u64 = 1002;
    const E_ARGS_NOT_MATCH: u64 = 1003;
    const E_NOT_STARTED: u64 = 1004;


    struct ManageCap<phantom T> has key, store {
        id: UID,
        claim_id: ID,
    }

    struct Claim<phantom T> has key, store {
        id: UID,
        emergency: bool,
        start_time: u64,
        end_time: u64,
        balance: Coin<T>,
        claim_members: Bag,
        unclaim_members: Bag,
    }

    public entry fun create_claim<T>(c: Coin<T>, start_time: u64, end_time: u64, ctx: &mut TxContext) {
        let claim = Claim {
            id: object::new(ctx),
            emergency: false,
            start_time,
            end_time,
            balance: c,
            claim_members: bag::new(ctx),
            unclaim_members: bag::new(ctx),
        };
        let manage_cap = ManageCap<T> {
            id: object::new(ctx),
            claim_id: object::id(&claim),
        };
        public_transfer(manage_cap, tx_context::sender(ctx));
        public_share_object(claim);
    }

    struct ClaimEvent has copy, drop {
        address: address,
        amount: u64,
    }

    public entry fun claim<T>(c: &mut Claim<T>, clock: &Clock, ctx: &mut TxContext) {
        assert!(!c.emergency, E_EMERGENCY_ON);
        let sender = tx_context::sender(ctx);
        assert!(bag::contains(&c.unclaim_members, sender), E_NOT_NEED_CLAIM);

        let current_time = clock::timestamp_ms(clock);
        assert!(current_time >= c.start_time && current_time <= c.end_time, E_NOT_STARTED);

        if (bag::contains(&c.claim_members, sender)) {
            let wait_cliam_amount = bag::borrow<address, u64>(&c.unclaim_members, sender);
            let claim_amount = bag::borrow_mut<address, u64>(&mut c.claim_members, sender);
            assert!(*wait_cliam_amount > *claim_amount, E_NOT_NEED_CLAIM);

            let claim = coin::split(&mut c.balance, *wait_cliam_amount - *claim_amount, ctx);
            *claim_amount = *wait_cliam_amount;
            public_transfer(claim, sender);

            event::emit(ClaimEvent {
                address: sender,
                amount: *wait_cliam_amount - *claim_amount,
            });
        } else {
            let wait_cliam_amount = bag::borrow<address, u64>(&c.unclaim_members, sender);
            let claim = coin::split(&mut c.balance, *wait_cliam_amount, ctx);
            bag::add(&mut c.claim_members, sender, *wait_cliam_amount);
            public_transfer(claim, sender);
            event::emit(ClaimEvent {
                address: sender,
                amount: *wait_cliam_amount,
            });
        }
    }

    public entry fun add_wait_claim_list<T>(
        c: &mut Claim<T>,
        adm: &ManageCap<T>,
        list: vector<address>,
        amounts: vector<u64>,
    ) {
        assert!(object::id(c) == adm.claim_id, E_OWNER_ONLY);
        let length = vector::length(&list);
        assert!(length == vector::length(&amounts), E_ARGS_NOT_MATCH);

        let i = 0;
        while (i < length) {
            let ads = vector::pop_back(&mut list);
            let amount = vector::pop_back(&mut amounts);
            if (bag::contains(&c.unclaim_members, ads)) {
                let amt = bag::borrow_mut<address,u64>(&mut c.unclaim_members, ads);
                *amt = amount;
            } else {
                bag::add(&mut c.unclaim_members, ads, amount);
            };
            i = i + 1;
        }
    }

    public entry fun emergency_switch<T>(c: &mut Claim<T>, adm: &ManageCap<T>) {
        assert!(object::id(c) == adm.claim_id, E_OWNER_ONLY);
        c.emergency = !c.emergency
    }

    public entry fun emergency_withdraw<T>(c: &mut Claim<T>, adm: &ManageCap<T>, ctx: &mut TxContext) {
        assert!(object::id(c) == adm.claim_id, E_OWNER_ONLY);
        let val = coin::value(&c.balance);
        let c = coin::split(&mut c.balance, val, ctx);
        public_transfer(c, tx_context::sender(ctx));
    }

    public entry fun emergency_depost<T>(c: &mut Claim<T>, adm: &ManageCap<T>, paid: Coin<T>) {
        assert!(object::id(c) == adm.claim_id, E_OWNER_ONLY);
        coin::join(&mut c.balance, paid);
    }

    #[test_only]
    const DECIMA: u64 = 1000000000;
    #[test_only]
    const START_TIMEL: u64 = 0;
    #[test_only]
    const END_TIME: u64 = 1;

    #[test]
    fun test_init_claim() {
        let ctx = tx_context::dummy();
        let sender = tx_context::sender(&mut ctx);
        let scenario = test_scenario::begin(sender);

        let s = coin::mint_for_testing<SUI>(1000 * DECIMA, &mut ctx);
        create_claim(s, START_TIMEL, END_TIME, &mut ctx);
        next_tx(&mut scenario, sender);
        let claim = test_scenario::take_shared<Claim<SUI>>(&mut scenario);

        assert!(claim.start_time == START_TIMEL, 1);
        assert!(claim.end_time == END_TIME, 2);

        test_scenario::return_shared(claim);
        end(scenario);
    }

    #[test]
    fun test_emergency_withdraw() {
        let ctx = tx_context::dummy();
        let sender = tx_context::sender(&mut ctx);
        let scenario = test_scenario::begin(sender);

        let s = coin::mint_for_testing<SUI>(1000 * DECIMA, &mut ctx);
        create_claim(s, START_TIMEL, END_TIME, &mut ctx);
        next_tx(&mut scenario, sender);
        let claim = test_scenario::take_shared<Claim<SUI>>(&mut scenario);
        let adm = test_scenario::take_from_sender<ManageCap<SUI>>(&mut scenario);

        assert!(claim.start_time == START_TIMEL, 1);
        assert!(claim.end_time == END_TIME, 2);
        assert!(coin::value(&claim.balance) == 1000 * DECIMA, 3);

        emergency_withdraw(&mut claim, &adm, &mut ctx);
        assert!(coin::value(&claim.balance) == 0, 4);

        test_scenario::return_to_sender(&mut scenario, adm);
        test_scenario::return_shared(claim);
        end(scenario);
    }

    #[test]
    fun test_claim() {
        let ctx = tx_context::dummy();
        let sender = tx_context::sender(&mut ctx);
        let scenario = test_scenario::begin(sender);

        let s = coin::mint_for_testing<SUI>(1000 * DECIMA, &mut ctx);
        create_claim(s, START_TIMEL, END_TIME, &mut ctx);
        let clock = clock::create_for_testing(&mut ctx);
        next_tx(&mut scenario, sender);
        let claim = test_scenario::take_shared<Claim<SUI>>(&mut scenario);
        let adm = test_scenario::take_from_sender<ManageCap<SUI>>(&mut scenario);

        let list = vector::empty<address>();
        let amounts = vector::empty<u64>();
        vector::push_back(&mut list, sender);
        vector::push_back(&mut amounts, 10 * DECIMA);
        vector::push_back(&mut list, sender);
        vector::push_back(&mut amounts, 10 * DECIMA);

        add_wait_claim_list(&mut claim, &adm, list, amounts);
        claim(&mut claim, &clock, &mut ctx);
        next_tx(&mut scenario, sender);
        let c = test_scenario::take_from_sender<Coin<SUI>>(&mut scenario);
        assert!(coin::value(&c) == 10 * DECIMA, 1);
        test_utils::destroy(c);
        test_utils::destroy(clock);
        test_scenario::return_to_sender(&mut scenario, adm);
        test_scenario::return_shared(claim);
        end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = E_NOT_NEED_CLAIM)]
    fun test_claim_twice() {
        let ctx = tx_context::dummy();
        let sender = tx_context::sender(&mut ctx);
        let scenario = test_scenario::begin(sender);
        let clock = clock::create_for_testing(&mut ctx);

        let s = coin::mint_for_testing<SUI>(1000 * DECIMA, &mut ctx);
        create_claim(s, START_TIMEL, END_TIME, &mut ctx);
        next_tx(&mut scenario, sender);
        let claim = test_scenario::take_shared<Claim<SUI>>(&mut scenario);
        let adm = test_scenario::take_from_sender<ManageCap<SUI>>(&mut scenario);

        let list = vector::empty<address>();
        let amounts = vector::empty<u64>();
        vector::push_back(&mut list, sender);
        vector::push_back(&mut amounts, 10 * DECIMA);

        add_wait_claim_list(&mut claim, &adm, list, amounts);
        claim(&mut claim, &clock, &mut ctx);
        next_tx(&mut scenario, sender);

        let c = test_scenario::take_from_sender<Coin<SUI>>(&mut scenario);
        assert!(coin::value(&c) == 10 * DECIMA, 1);
        claim(&mut claim, &clock, &mut ctx);

        test_utils::destroy(c);
        test_utils::destroy(clock);
        test_scenario::return_to_sender(&mut scenario, adm);
        test_scenario::return_shared(claim);
        end(scenario);
    }

    #[test]
    #[expected_failure]
    fun test_emergency() {
        let ctx = tx_context::dummy();
        let sender = tx_context::sender(&mut ctx);
        let scenario = test_scenario::begin(sender);
        let clock = clock::create_for_testing(&mut ctx);

        let s = coin::mint_for_testing<SUI>(1000 * DECIMA, &mut ctx);
        create_claim(s, START_TIMEL, END_TIME, &mut ctx);
        next_tx(&mut scenario, sender);
        let claim = test_scenario::take_shared<Claim<SUI>>(&mut scenario);
        let adm = test_scenario::take_from_sender<ManageCap<SUI>>(&mut scenario);
        emergency_switch(&mut claim, &adm);
        let list = vector::empty<address>();
        let amounts = vector::empty<u64>();
        vector::push_back(&mut list, sender);
        vector::push_back(&mut amounts, 10 * DECIMA);

        add_wait_claim_list(&mut claim, &adm, list, amounts);
        claim(&mut claim, &clock, &mut ctx);

        test_utils::destroy(clock);
        test_scenario::return_to_sender(&mut scenario, adm);
        test_scenario::return_shared(claim);
        end(scenario);
    }
}

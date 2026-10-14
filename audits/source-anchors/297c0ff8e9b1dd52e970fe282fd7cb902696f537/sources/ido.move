module presale::ido {
    use std::vector;

    use sui::bag::{Self, Bag};
    use sui::clock::{Self, Clock};
    use sui::coin::{Self, Coin};
    use sui::event;
    use sui::object::{Self, UID, ID};
    use sui::transfer::{public_share_object, public_transfer};
    use sui::tx_context::{Self, TxContext};

    #[test_only]
    use sui::coin::mint_for_testing;
    #[test_only]
    use sui::sui::SUI;
    #[test_only]
    use sui::test_scenario::{Self, end, next_tx};
    #[test_only]
    use sui::test_utils;

    const NOT_WHITELIST: u64 = 1000;
    const NOT_STARTED: u64 = 1001;
    const MAX_CAP_REACHED: u64 = 1002;
    const OWNER_ONLY: u64 = 1003;
    const USER_MAX_CAP_REACHED: u64 = 1004;
    const USER_MIN_CAP_REACHED: u64 = 1005;

    struct ManageCapAbility<phantom T> has key, store {
        id: UID,
        sale_id: ID,
    }

    struct PreSale<phantom T> has key, store {
        id: UID,
        status: u8,
        only_whitelist: bool,
        raise: u64,
        start_time: u64,
        end_time: u64,
        min_amount: u64,
        max_amount: u64,
        balance: Coin<T>,
        white_listed: Bag,
        members: Bag,
    }

    struct SaleEvent has copy, drop {
        address: address,
        amount: u64,
    }


    public entry fun create_presale<T>(
        start_time: u64,
        end_time: u64,
        raise: u64,
        min_amount: u64,
        max_amount: u64,
        ctx: &mut TxContext
    ) {
        let presale = PreSale<T> {
            id: object::new(ctx),
            status: 0,
            only_whitelist: false,
            raise,
            start_time,
            end_time,
            min_amount,
            max_amount,
            balance: coin::zero<T>(ctx),
            white_listed: bag::new(ctx),
            members: bag::new(ctx),
        };

        public_transfer(ManageCapAbility<T> {
            id: object::new(ctx),
            sale_id: object::id(&presale)
        }, tx_context::sender(ctx));

        public_share_object(presale);
    }


    fun is_whitelisted<T>(sale: &PreSale<T>, address: address): bool {
        bag::contains(&sale.white_listed, address)
    }

    public entry fun fund<T>(sale: &mut PreSale<T>, payment: Coin<T>, clock: &Clock, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);
        if (sale.only_whitelist) {
            assert!(is_whitelisted(sale, sender), NOT_WHITELIST);
        };

        let current_time = clock::timestamp_ms(clock);
        assert!(current_time >= sale.start_time && current_time <= sale.end_time, NOT_STARTED);


        let amount = coin::value(&payment);
        let balance = coin::value(&sale.balance);

        assert!(balance + amount <= sale.raise, MAX_CAP_REACHED);
        assert!(amount <= sale.max_amount, USER_MAX_CAP_REACHED);
        assert!(amount >= sale.min_amount, USER_MAX_CAP_REACHED);
        coin::join(&mut sale.balance, payment);
        event::emit(SaleEvent {
            address: sender,
            amount,
        });

        if (bag::contains(&mut sale.members, sender)) {
            let account_amount = bag::borrow_mut<address, u64>(&mut sale.members, sender);

            assert!((*account_amount + amount) <= sale.max_amount, USER_MAX_CAP_REACHED);
            *account_amount = (*account_amount + amount);
        } else {
            bag::add(&mut sale.members, sender, amount);
        }
    }

    public entry fun transfer_funds<T>(
        sale: &mut PreSale<T>,
        manage: &ManageCapAbility<T>,
        recipient: address,
        ctx: &mut TxContext
    ) {
        assert!(object::id(sale) == manage.sale_id, OWNER_ONLY);

        let amount = coin::value(&sale.balance);
        let split_amount = coin::split(&mut sale.balance, amount, ctx);

        public_transfer(split_amount, recipient);
    }

    public entry fun transfer_funds_to_self<T>(
        sale: &mut PreSale<T>,
        manage: &ManageCapAbility<T>,
        ctx: &mut TxContext
    ) {
        assert!(object::id(sale) == manage.sale_id, OWNER_ONLY);

        let amount = coin::value(&sale.balance);
        let split_amount = coin::split(&mut sale.balance, amount, ctx);

        public_transfer(split_amount, tx_context::sender(ctx));
    }

    public entry fun set_pub_or_wihte_listed_only<T>(
        sale: &mut PreSale<T>,
        manage: &ManageCapAbility<T>
    ) {
        assert!(object::id(sale) == manage.sale_id, OWNER_ONLY);
        sale.only_whitelist = !sale.only_whitelist;
    }

    public entry fun add_white_list<T>(
        sale: &mut PreSale<T>,
        manage: &ManageCapAbility<T>,
        list: vector<address>
    ) {
        assert!(object::id(sale) == manage.sale_id, OWNER_ONLY);
        let length = vector::length(&list);
        let i = 0;
        while (i < length) {
            let address = vector::pop_back(&mut list);
            if (!is_whitelisted(sale, address)) {
                bag::add(&mut sale.white_listed, address, true);
            };
            i = i + 1;
        }
    }

    public entry fun increment_endtime<T>(
        sale: &mut PreSale<T>,
        manage: &ManageCapAbility<T>,
        end_time: u64
    ) {
        assert!(object::id(sale) == manage.sale_id, OWNER_ONLY);
        sale.end_time = end_time;
    }

    public entry fun increment_starttime<T>(
        sale: &mut PreSale<T>,
        manage: &ManageCapAbility<T>,
        start_time: u64
    ) {
        assert!(object::id(sale) == manage.sale_id, OWNER_ONLY);
        sale.start_time = start_time;
    }

    #[test_only]
    const DECIMA: u64 = 1000000000;
    #[test_only]
    const START_TIMEL: u64 = 0;
    #[test_only]
    const END_TIME: u64 = 1;

    #[test]
    fun test_wihte_list() {
        let ctx = tx_context::dummy();
        let sender = tx_context::sender(&mut ctx);
        let scenario = test_scenario::begin(sender);
        create_presale<SUI>(START_TIMEL, END_TIME, 100 * DECIMA, 1 * DECIMA, 5 * DECIMA, &mut ctx);
        next_tx(&mut scenario, sender);
        let presale = test_scenario::take_shared<PreSale<SUI>>(&mut scenario);
        let cap = test_scenario::take_from_sender<ManageCapAbility<SUI>>(&mut scenario);

        let list = vector::empty();
        vector::push_back(&mut list, sender);
        set_pub_or_wihte_listed_only(&mut presale, &mut cap);
        add_white_list(&mut presale, &mut cap, list);
        let coin = mint_for_testing<SUI>(5 * DECIMA, &mut ctx);
        let clock = clock::create_for_testing(&mut ctx);

        fund(&mut presale, coin, &clock, &mut ctx);

        test_utils::destroy(clock);
        test_scenario::return_to_sender(&mut scenario, cap);
        test_scenario::return_shared(presale);
        end(scenario);
    }

    #[test]
    #[expected_failure]
    fun test_wihte_list_only() {
        let ctx = tx_context::dummy();
        let sender = tx_context::sender(&mut ctx);
        let scenario = test_scenario::begin(sender);
        create_presale<SUI>(START_TIMEL, END_TIME, 100 * DECIMA, 1 * DECIMA, 5 * DECIMA, &mut ctx);
        next_tx(&mut scenario, sender);
        let presale = test_scenario::take_shared<PreSale<SUI>>(&mut scenario);
        let cap = test_scenario::take_from_sender<ManageCapAbility<SUI>>(&mut scenario);
        let coin = mint_for_testing<SUI>(5 * DECIMA, &mut ctx);
        let clock = clock::create_for_testing(&mut ctx);
        fund(&mut presale, coin, &clock, &mut ctx);
        assert!(coin::value(&presale.balance) == 5 * DECIMA, 1);

        set_pub_or_wihte_listed_only(&mut presale, &mut cap);
        let coin = mint_for_testing<SUI>(5 * DECIMA, &mut ctx);
        fund(&mut presale, coin, &clock, &mut ctx);

        test_utils::destroy(clock);
        test_scenario::return_to_sender(&mut scenario, cap);
        test_scenario::return_shared(presale);
        end(scenario);
    }

    #[test]
    #[expected_failure]
    fun test_manage_ablitiy() {
        let ctx = tx_context::dummy();
        let sender = tx_context::sender(&mut ctx);
        let scenario = test_scenario::begin(sender);
        create_presale<SUI>(START_TIMEL, END_TIME, 100 * DECIMA, 1 * DECIMA, 5 * DECIMA, &mut ctx);
        next_tx(&mut scenario, sender);
        let presale = test_scenario::take_shared<PreSale<SUI>>(&mut scenario);
        let cap = ManageCapAbility<SUI> {
            id: object::new(&mut ctx),
            sale_id: object::id(&presale),
        };
        set_pub_or_wihte_listed_only(&mut presale, &cap);
        cap.sale_id = object::id(&cap);
        set_pub_or_wihte_listed_only(&mut presale, &cap);

        test_utils::destroy(cap);
        test_scenario::return_shared(presale);
        end(scenario);
    }

    #[test]
    #[expected_failure]
    fun test_fund_twice() {
        let ctx = tx_context::dummy();
        let sender = tx_context::sender(&mut ctx);
        let scenario = test_scenario::begin(sender);
        create_presale<SUI>(START_TIMEL, END_TIME, 100 * DECIMA, 1 * DECIMA, 5 * DECIMA, &mut ctx);
        next_tx(&mut scenario, sender);
        let presale = test_scenario::take_shared<PreSale<SUI>>(&mut scenario);
        let cap = test_scenario::take_from_sender<ManageCapAbility<SUI>>(&mut scenario);
        let coin = mint_for_testing<SUI>(5 * DECIMA, &mut ctx);
        let clock = clock::create_for_testing(&mut ctx);
        fund(&mut presale, coin, &clock, &mut ctx);
        assert!(coin::value(&presale.balance) == 5 * DECIMA, 1);

        let coin = mint_for_testing<SUI>(5 * DECIMA, &mut ctx);
        fund(&mut presale, coin, &clock, &mut ctx);
        assert!(coin::value(&presale.balance) == 5 * DECIMA, 1);

        test_utils::destroy(clock);
        test_scenario::return_to_sender(&mut scenario, cap);
        test_scenario::return_shared(presale);
        end(scenario);
    }

    #[test]
    fun test_fund_save() {
        let ctx = tx_context::dummy();
        let sender = tx_context::sender(&mut ctx);
        let scenario = test_scenario::begin(sender);
        create_presale<SUI>(START_TIMEL, END_TIME, 100 * DECIMA, 1 * DECIMA, 1 * DECIMA, &mut ctx);
        next_tx(&mut scenario, sender);
        let presale = test_scenario::take_shared<PreSale<SUI>>(&mut scenario);
        let cap = test_scenario::take_from_sender<ManageCapAbility<SUI>>(&mut scenario);
        let coin = mint_for_testing<SUI>(1 * DECIMA, &mut ctx);
        let clock = clock::create_for_testing(&mut ctx);
        fund(&mut presale, coin, &clock, &mut ctx);
        assert!(coin::value(&presale.balance) == 1 * DECIMA, 1);

        test_utils::destroy(clock);
        test_scenario::return_to_sender(&mut scenario, cap);
        test_scenario::return_shared(presale);
        end(scenario);
    }

    #[test]
    fun test_fund() {
        let ctx = tx_context::dummy();
        let sender = tx_context::sender(&mut ctx);
        let scenario = test_scenario::begin(sender);
        create_presale<SUI>(START_TIMEL, END_TIME, 100 * DECIMA, 1 * DECIMA, 5 * DECIMA, &mut ctx);
        next_tx(&mut scenario, sender);
        let presale = test_scenario::take_shared<PreSale<SUI>>(&mut scenario);
        let cap = test_scenario::take_from_sender<ManageCapAbility<SUI>>(&mut scenario);
        let coin = mint_for_testing<SUI>(2 * DECIMA, &mut ctx);
        let clock = clock::create_for_testing(&mut ctx);
        fund(&mut presale, coin, &clock, &mut ctx);
        assert!(coin::value(&presale.balance) == 2 * DECIMA, 1);

        let coin = mint_for_testing<SUI>(2 * DECIMA, &mut ctx);
        fund(&mut presale, coin, &clock, &mut ctx);
        let amount = bag::borrow<address, u64>(&presale.members, sender);
        assert!(*amount == (4 * DECIMA), 1);
        assert!(coin::value(&presale.balance) == 4 * DECIMA, 1);

        let coin = mint_for_testing<SUI>(1 * DECIMA, &mut ctx);
        fund(&mut presale, coin, &clock, &mut ctx);
        let amount = bag::borrow<address, u64>(&presale.members, sender);
        assert!(*amount == (5 * DECIMA), 1);
        assert!(coin::value(&presale.balance) == 5 * DECIMA, 1);


        test_utils::destroy(clock);
        test_scenario::return_to_sender(&mut scenario, cap);
        test_scenario::return_shared(presale);
        end(scenario);
    }

    #[test]
    fun test_fund_max() {
        let ctx = tx_context::dummy();
        let sender = tx_context::sender(&mut ctx);
        let scenario = test_scenario::begin(sender);
        create_presale<SUI>(START_TIMEL, END_TIME, 6 * DECIMA, 1 * DECIMA, 6 * DECIMA, &mut ctx);
        next_tx(&mut scenario, sender);
        let presale = test_scenario::take_shared<PreSale<SUI>>(&mut scenario);
        let cap = test_scenario::take_from_sender<ManageCapAbility<SUI>>(&mut scenario);
        let coin = mint_for_testing<SUI>(2 * DECIMA, &mut ctx);
        let clock = clock::create_for_testing(&mut ctx);
        fund(&mut presale, coin, &clock, &mut ctx);
        assert!(coin::value(&presale.balance) == 2 * DECIMA, 1);

        let coin = mint_for_testing<SUI>(2 * DECIMA, &mut ctx);
        fund(&mut presale, coin, &clock, &mut ctx);
        let amount = bag::borrow<address, u64>(&presale.members, sender);
        assert!(*amount == (4 * DECIMA), 1);
        assert!(coin::value(&presale.balance) == 4 * DECIMA, 1);

        let coin = mint_for_testing<SUI>(1 * DECIMA, &mut ctx);
        fund(&mut presale, coin, &clock, &mut ctx);
        let amount = bag::borrow<address, u64>(&presale.members, sender);
        assert!(*amount == (5 * DECIMA), 1);
        assert!(coin::value(&presale.balance) == 5 * DECIMA, 1);

        let coin = mint_for_testing<SUI>(1 * DECIMA, &mut ctx);
        fund(&mut presale, coin, &clock, &mut ctx);
        let amount = bag::borrow<address, u64>(&presale.members, sender);
        assert!(*amount == (6 * DECIMA), 1);
        assert!(coin::value(&presale.balance) == 6 * DECIMA, 1);

        test_utils::destroy(clock);
        test_scenario::return_to_sender(&mut scenario, cap);
        test_scenario::return_shared(presale);
        end(scenario);
    }

    #[test]
    #[expected_failure]
    fun test_fund_outof_max() {
        let ctx = tx_context::dummy();
        let sender = tx_context::sender(&mut ctx);
        let scenario = test_scenario::begin(sender);
        create_presale<SUI>(START_TIMEL, END_TIME, 6 * DECIMA, 1 * DECIMA, 6 * DECIMA, &mut ctx);
        next_tx(&mut scenario, sender);
        let presale = test_scenario::take_shared<PreSale<SUI>>(&mut scenario);
        let cap = test_scenario::take_from_sender<ManageCapAbility<SUI>>(&mut scenario);
        let coin = mint_for_testing<SUI>(2 * DECIMA, &mut ctx);
        let clock = clock::create_for_testing(&mut ctx);
        fund(&mut presale, coin, &clock, &mut ctx);
        assert!(coin::value(&presale.balance) == 2 * DECIMA, 1);

        let coin = mint_for_testing<SUI>(2 * DECIMA, &mut ctx);
        fund(&mut presale, coin, &clock, &mut ctx);
        let amount = bag::borrow<address, u64>(&presale.members, sender);
        assert!(*amount == (4 * DECIMA), 1);
        assert!(coin::value(&presale.balance) == 4 * DECIMA, 1);

        let coin = mint_for_testing<SUI>(1 * DECIMA, &mut ctx);
        fund(&mut presale, coin, &clock, &mut ctx);
        let amount = bag::borrow<address, u64>(&presale.members, sender);
        assert!(*amount == (5 * DECIMA), 1);
        assert!(coin::value(&presale.balance) == 5 * DECIMA, 1);

        let coin = mint_for_testing<SUI>(2 * DECIMA, &mut ctx);
        fund(&mut presale, coin, &clock, &mut ctx);
        let amount = bag::borrow<address, u64>(&presale.members, sender);
        assert!(*amount == (7 * DECIMA), 1);
        assert!(coin::value(&presale.balance) == 7 * DECIMA, 1);

        test_utils::destroy(clock);
        test_scenario::return_to_sender(&mut scenario, cap);
        test_scenario::return_shared(presale);
        end(scenario);
    }

    #[test]
    fun test_fund_transfer() {
        let ctx = tx_context::dummy();
        let sender = tx_context::sender(&mut ctx);
        let scenario = test_scenario::begin(sender);
        create_presale<SUI>(START_TIMEL, END_TIME, 6 * DECIMA, 1 * DECIMA, 6 * DECIMA, &mut ctx);
        next_tx(&mut scenario, sender);
        let presale = test_scenario::take_shared<PreSale<SUI>>(&mut scenario);
        let cap = test_scenario::take_from_sender<ManageCapAbility<SUI>>(&mut scenario);
        let coin = mint_for_testing<SUI>(2 * DECIMA, &mut ctx);
        let clock = clock::create_for_testing(&mut ctx);
        fund(&mut presale, coin, &clock, &mut ctx);
        assert!(coin::value(&presale.balance) == 2 * DECIMA, 1);
        next_tx(&mut scenario, sender);
        transfer_funds_to_self(&mut presale, &cap, &mut ctx);
        assert!(coin::value(&presale.balance) == 0 * DECIMA, 2);
        next_tx(&mut scenario, sender);
        let amount = test_scenario::take_from_sender<Coin<SUI>>(&mut scenario);
        assert!(coin::value(&amount) == 2 * DECIMA, 3);

        test_utils::destroy(clock);
        test_scenario::return_to_sender(&mut scenario, amount);
        test_scenario::return_to_sender(&mut scenario, cap);
        test_scenario::return_shared(presale);
        end(scenario);
    }

    #[test]
    fun test_fund_transfer_to() {
        let ctx = tx_context::dummy();
        let sender = tx_context::sender(&mut ctx);
        let scenario = test_scenario::begin(sender);
        create_presale<SUI>(START_TIMEL, END_TIME, 6 * DECIMA, 1 * DECIMA, 6 * DECIMA, &mut ctx);
        next_tx(&mut scenario, sender);
        let presale = test_scenario::take_shared<PreSale<SUI>>(&mut scenario);
        let cap = test_scenario::take_from_sender<ManageCapAbility<SUI>>(&mut scenario);
        let coin = mint_for_testing<SUI>(2 * DECIMA, &mut ctx);
        let clock = clock::create_for_testing(&mut ctx);
        fund(&mut presale, coin, &clock, &mut ctx);
        assert!(coin::value(&presale.balance) == 2 * DECIMA, 1);

        transfer_funds(&mut presale, &cap, sender, &mut ctx);
        assert!(coin::value(&presale.balance) == 0 * DECIMA, 2);
        next_tx(&mut scenario, sender);
        let amount = test_scenario::take_from_sender<Coin<SUI>>(&mut scenario);
        assert!(coin::value(&amount) == 2 * DECIMA, 3);


        test_utils::destroy(clock);
        test_scenario::return_to_sender(&mut scenario, amount);
        test_scenario::return_to_sender(&mut scenario, cap);
        test_scenario::return_shared(presale);
        end(scenario);
    }

    #[test]
    #[expected_failure]
    fun test_starttime() {
        let ctx = tx_context::dummy();
        let sender = tx_context::sender(&mut ctx);
        let scenario = test_scenario::begin(sender);
        create_presale<SUI>(START_TIMEL + 1, END_TIME, 100 * DECIMA, 1 * DECIMA, 5 * DECIMA, &mut ctx);
        next_tx(&mut scenario, sender);
        let presale = test_scenario::take_shared<PreSale<SUI>>(&mut scenario);
        let cap = test_scenario::take_from_sender<ManageCapAbility<SUI>>(&mut scenario);
        let coin = mint_for_testing<SUI>(5 * DECIMA, &mut ctx);
        let clock = clock::create_for_testing(&mut ctx);
        fund(&mut presale, coin, &clock, &mut ctx);
        assert!(coin::value(&presale.balance) == 5 * DECIMA, 1);

        test_utils::destroy(clock);
        test_scenario::return_to_sender(&mut scenario, cap);
        test_scenario::return_shared(presale);
        end(scenario);
    }

    #[test]
    #[expected_failure]
    fun test_endtime() {
        let ctx = tx_context::dummy();
        let sender = tx_context::sender(&mut ctx);
        let scenario = test_scenario::begin(sender);
        create_presale<SUI>(START_TIMEL, END_TIME - 1, 100 * DECIMA, 1 * DECIMA, 5 * DECIMA, &mut ctx);
        next_tx(&mut scenario, sender);
        let presale = test_scenario::take_shared<PreSale<SUI>>(&mut scenario);
        let cap = test_scenario::take_from_sender<ManageCapAbility<SUI>>(&mut scenario);
        let coin = mint_for_testing<SUI>(5 * DECIMA, &mut ctx);
        let clock = clock::create_for_testing(&mut ctx);
        clock::increment_for_testing(&mut clock, END_TIME);
        fund(&mut presale, coin, &clock, &mut ctx);
        assert!(coin::value(&presale.balance) == 5 * DECIMA, 1);

        test_utils::destroy(clock);
        test_scenario::return_to_sender(&mut scenario, cap);
        test_scenario::return_shared(presale);
        end(scenario);
    }

    #[test]
    fun test_init_presale() {
        let ctx = tx_context::dummy();
        let sender = tx_context::sender(&mut ctx);
        let scenario = test_scenario::begin(sender);
        create_presale<SUI>(START_TIMEL, END_TIME, 100 * DECIMA, 1 * DECIMA, 5 * DECIMA, &mut ctx);
        next_tx(&mut scenario, sender);
        let presale = test_scenario::take_shared<PreSale<SUI>>(&mut scenario);

        assert!(presale.start_time == START_TIMEL, 1);
        assert!(presale.end_time == END_TIME, 2);
        assert!(presale.raise == 100 * DECIMA, 3);
        assert!(presale.min_amount == 1 * DECIMA, 4);
        assert!(presale.max_amount == 5 * DECIMA, 5);

        test_scenario::return_shared(presale);
        end(scenario);
    }

    #[test]
    fun test_all() {}
}

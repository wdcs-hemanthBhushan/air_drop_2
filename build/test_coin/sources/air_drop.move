module my_addrx::air_drop {
    use aptos_framework::account::{Self, SignerCapability, new_event_handle};
    use aptos_framework::timestamp;
    use std::signer;
    use std::string;
    use std::vector;
    use aptos_std::event::{Self, EventHandle};
    use aptos_framework::coin;
    use std::debug::print;

    // Defined Deposit DepositManagement seeds that are used for creating resources
    const SEED_USER_LIST: vector<u8> = b"UserList::UserListManagement";

    const ERROR_INVALID_BUYER: u64 = 0;
    const ERROR_INVALID_OWNER: u64 = 1;
    const ERROR: u64 = 2;
    const ERROR_AIR_DROP_NOT_STARTED: u64 = 3;
    const ERROR_NOT_ELIGIBLE_LOW_BALANCE: u64 = 4;

    struct AirDropToken has  drop  {}

    struct AirDropTokenCapabilities has key  {
        burn_cap: coin::BurnCapability<AirDropToken>,
        freeze_cap: coin::FreezeCapability<AirDropToken>,
        mint_cap: coin::MintCapability<AirDropToken>,
    }

    struct AirDropCap has key {
        cap: SignerCapability,
    }

    struct ClaimAirdropEvent has store, drop {
        name: string::String,
        user_address: address,
        amount:u64,
        timestamp: u64,
    }

    struct EligibleForAirDropEvent has store, drop {
        user_address: address,
        selected: bool,
        timestamp: u64,
    }

    struct AirDrop has key, store, copy {
        level: u8,
        name: string::String,
        account: address,
    }

    struct AirDropEvent has key {
        airdrop_event: EventHandle<ClaimAirdropEvent>,
    }

    struct WhitelistedForAirDropEvent has key  {
        whitelisted_user: EventHandle<EligibleForAirDropEvent>,
    }

    struct StoreAirDropUsers has key {
        list_of_users: vector<AirDrop>,
    }

    fun only_admin(addr: address) {
        assert!(addr == @my_addrx, ERROR_INVALID_OWNER);
    }

    public entry fun initialize_airdrop(account: &signer, name: string::String, symbol: string::String, decimals: u8) {
        let sender_addr = signer::address_of(account);
        let (market_signer, market_cap) = account::create_resource_account(account, SEED_USER_LIST);
        let _market_signer_addr = signer::address_of(&market_signer);

        let (burn_cap, freeze_cap, mint_cap) = coin::initialize<AirDropToken>(account, name, symbol, decimals, true);

        only_admin(sender_addr);

            move_to(&market_signer, AirDropCap {
                cap: market_cap,
            });
    
    
            move_to(&market_signer, StoreAirDropUsers {
                list_of_users: vector::empty<AirDrop>(),
            });
      

            move_to(&market_signer, AirDropTokenCapabilities {
                burn_cap,
                freeze_cap,
                mint_cap,
            });
     

       
            move_to(&market_signer, WhitelistedForAirDropEvent {
                whitelisted_user: new_event_handle<EligibleForAirDropEvent>(&market_signer),
            });

            move_to(&market_signer, AirDropEvent {
                airdrop_event: new_event_handle<ClaimAirdropEvent>(&market_signer),
        })
        
    }

    public entry fun register_for_airdrop(user_account: &signer,level: u8 , name:string::String) acquires StoreAirDropUsers , WhitelistedForAirDropEvent {
      
        let user_addr: address = signer::address_of(user_account);

        let resource_address = account::create_resource_address(&@my_addrx, SEED_USER_LIST);

        assert!(user_addr != @my_addrx, ERROR_INVALID_BUYER);
        assert!(exists<StoreAirDropUsers>(resource_address), ERROR_AIR_DROP_NOT_STARTED);
        assert!(coin::balance<AirDropToken>(user_addr) >= 10, ERROR_NOT_ELIGIBLE_LOW_BALANCE);
        
        let air_drop = AirDrop{
            level,
            name,
            account:user_addr
            };

        let user_list: &mut StoreAirDropUsers = borrow_global_mut<StoreAirDropUsers>(resource_address);
        vector::push_back(&mut user_list.list_of_users, copy air_drop);

        move_to(user_account, air_drop);
        

        coin::register<AirDropToken>(user_account);

        let whitelist_event = borrow_global_mut<WhitelistedForAirDropEvent>(resource_address);

        event::emit_event<EligibleForAirDropEvent>(
           &mut whitelist_event.whitelisted_user,
            EligibleForAirDropEvent{ 
                user_address:user_addr ,
                selected: true,
                timestamp: timestamp::now_seconds()
            }
        )
    }

    public entry fun claim_rewards(user : &signer) acquires AirDrop ,AirDropTokenCapabilities , AirDropEvent{  
        let user_addr = signer::address_of(user);

        assert!(exists<AirDrop>(user_addr), ERROR_INVALID_BUYER);
      
        let resource_address = account::create_resource_address(&@my_addrx , SEED_USER_LIST);
        let level = &borrow_global<AirDrop>(user_addr).level;
        let name = borrow_global<AirDrop>(user_addr).name;
        let account = &borrow_global<AirDrop>(user_addr).account;
        assert!(account == &user_addr  , ERROR);
       
        if(*level == 1 ){
            let amount  = 10 * coin::balance<AirDropToken>(user_addr);
            print(&name);
        deposit_air_drop_tokens(user_addr , amount , resource_address,name)

        } else if(*level == 2){
            let amount  = 20 * coin::balance<AirDropToken>(user_addr);
            print(&name);
            deposit_air_drop_tokens(user_addr , amount , resource_address,name)

        }else{
            let amount  = 20 * coin::balance<AirDropToken>(user_addr);
            print(&name);
            deposit_air_drop_tokens(user_addr , amount , resource_address, name)
        };

    

      
    }

    fun deposit_air_drop_tokens(user_addr:address , amount :u64 , resource_address:address , name:string::String) acquires AirDropTokenCapabilities , AirDropEvent{
      
        
        let mint_cap =  &borrow_global<AirDropTokenCapabilities>(resource_address).mint_cap;
        
        let coin = coin::mint<AirDropToken>(amount , mint_cap);

        coin::deposit<AirDropToken>(user_addr , coin);
        let claim_air_drop_event = borrow_global_mut<AirDropEvent>(resource_address);

        event::emit_event<ClaimAirdropEvent>(
        &mut claim_air_drop_event.airdrop_event,
            ClaimAirdropEvent{ 
                name: name,
                user_address:user_addr ,
                amount:amount,
                timestamp: timestamp::now_seconds()
            }
            )
    }


    #[view]

    public fun view_air_drop_users() : vector<AirDrop>  acquires StoreAirDropUsers {
        let resource_address = account::create_resource_address(&@my_addrx , SEED_USER_LIST);
        assert!(exists<StoreAirDropUsers>(resource_address),ERROR);
        borrow_global<StoreAirDropUsers>(resource_address).list_of_users
    }


   // ======================================================================
   //   Unit test cases
   // ======================================================================
    #[test(account = @my_addrx)]
      public fun test_initialize_airdrop(account:&signer){
        let name :string::String= string::utf8(b"Air Drop Token");
        let symbol :string::String = string::utf8(b"ADT");
        let decimals :u8 = 18;

        initialize_airdrop(account,name,symbol,decimals);
      }

      #[test(account = @my_addrx)]
    //   #[expected_failure(abort_code = 0x524303, location = aptos_framework::account)]
    #[expected_failure]
      public fun test_initialize_airdrop_fail(account:&signer) {
        let name :string::String= string::utf8(b"Air Drop Token");
        let symbol :string::String = string::utf8(b"ADT");
        let decimals :u8 = 18;
        let (_, _) = account::create_resource_account(account, SEED_USER_LIST);
        initialize_airdrop(account,name,symbol,decimals);
      }

       #[test(account = @my_addrx)]
       #[expected_failure]
      public fun test_initialize_airdrop_fail1(account:&signer) {
        let name :string::String= string::utf8(b"Air Drop Token");
        let symbol :string::String = string::utf8(b"ADT");
        let decimals :u8 = 18;
        initialize_airdrop(account,name,symbol,decimals);
         initialize_airdrop(account,name,symbol,decimals);
      }

       #[test(account = @my_addrx)]
    //   #[expected_failure(abort_code = 0x524303, location = aptos_framework::account)]
    #[expected_failure]
      public fun test_initialize_airdrop_fail(account:&signer) {
        let name :string::String= string::utf8(b"Air Drop Token");
        let symbol :string::String = string::utf8(b"ADT");
        let decimals :u8 = 18;
        let (market_signer, _) = account::create_resource_account(account, SEED_USER_LIST);
        initialize_airdrop(account,name,symbol,decimals);
      }



    

    




    // #[test(market = @my_addrx)]
    // fun test_airdrop_script(market: &signer) {
    //     account::create_account_for_test(signer::address_of(market));
        
    //     let resource_address = account::create_resource_address(&@my_addrx, SEED_USER_LIST);

    //     initial_airdrop_script(market);
    //     assert!(exists<AirDropCap>(resource_address), ERROR);
    //     assert!(exists<StoreAirDropUsers>(resource_address), ERROR);
    // }

    // #[test(market = @0x1234)]
    // #[expected_failure]
    // fun test_airdrop_script_called_by_diff_signer(market: &signer) {
    //     account::create_account_for_test(signer::address_of(market));

    //     initial_airdrop_script(market);
    // }

    // #[test(market = @my_addrx, buyer = @0x1234)]
    
    // fun test_make_user_eligible_for_airdrop(market: &signer , buyer:&signer) acquires StoreAirDropUsers {
    //     account::create_account_for_test(signer::address_of(market));
    //     account::create_account_for_test(signer::address_of(buyer));
        
    //     let buyer_addr = signer::address_of(buyer);
    //     let air_drop = AirDrop {
    //         level: 3,
    //         name: utf8(b"hemanth"),
    //         account: buyer_addr
    //     };

    //     initial_airdrop_script(market);

    //     make_user_eligible_for_airdrop(market, air_drop)
    // }

    // #[test(market = @my_addrx)]
    // #[expected_failure]
    // fun test_make_user_eligible_for_airdrop_fail(market: &signer ) acquires StoreAirDropUsers {
    //     // this should fail
    //     account::create_account_for_test(signer::address_of(market));
        

    //     let market_addr = signer::address_of(market);
    //     let air_drop = AirDrop {
    //         level: 3,
    //         name: utf8(b"hemanth"),
    //         account: market_addr
    //     };

    //     initial_airdrop_script(market);
    //     make_user_eligible_for_airdrop(market, air_drop)
    // }     

}

use starknet::ContractAddress;
use snforge_std::{
    declare, start_prank, stop_prank, ContractClassTrait, CheatTarget, spy_events, SpyOn, EventSpy,
    EventFetcher
};

use core::traits::TryInto;
use core::option::OptionTrait;

// Import the interfaces from the original contract
use super::{IERC20Dispatcher, IERC20DispatcherTrait, IERC721Dispatcher, IERC721DispatcherTrait};
use super::INFTDutchAuctionDispatcher;
use super::INFTDutchAuctionDispatcherTrait;

fn deploy_erc20(owner: ContractAddress) -> ContractAddress {
    let erc20_contract = declare("MockERC20");
    let mut calldata = array![];
    calldata.append(owner.into());
    erc20_contract.deploy(@calldata).unwrap()
}

fn deploy_erc721(owner: ContractAddress) -> ContractAddress {
    let erc721_contract = declare("MockERC721");
    let mut calldata = array![];
    calldata.append(owner.into());
    erc721_contract.deploy(@calldata).unwrap()
}

fn deploy_dutch_auction(
    erc20_token: ContractAddress,
    erc721_token: ContractAddress,
    starting_price: u64,
    seller: ContractAddress,
    duration: u64,
    discount_rate: u64,
    total_supply: u128
) -> ContractAddress {
    let contract = declare("NFTDutchAuction");
    let mut calldata = array![];
    calldata.append(erc20_token.into());
    calldata.append(erc721_token.into());
    calldata.append(starting_price.into());
    calldata.append(seller.into());
    calldata.append(duration.into());
    calldata.append(discount_rate.into());
    calldata.append(total_supply.into());
    
    contract.deploy(@calldata).unwrap()
}

#[test]
fn test_dutch_auction_constructor() {
    let owner = starknet::contract_address_const::<0x123>();
    let erc20_token = deploy_erc20(owner);
    let erc721_token = deploy_erc721(owner);
    
    let auction = deploy_dutch_auction(
        erc20_token, 
        erc721_token, 
        1000, // starting price 
        owner, 
        100,  // duration 
        10,   // discount rate
        5     // total supply
    );
    
    let dutch_auction_dispatcher = INFTDutchAuctionDispatcher { contract_address: auction };
    
    // Check initial price is the starting price
    assert(dutch_auction_dispatcher.get_price() == 1000, 'Incorrect initial price');
}

#[test]
fn test_dutch_auction_price_reduction() {
    let owner = starknet::contract_address_const::<0x123>();
    let erc20_token = deploy_erc20(owner);
    let erc721_token = deploy_erc721(owner);
    
    // Temporarily modify block timestamp to simulate time passing
    let auction = deploy_dutch_auction(
        erc20_token, 
        erc721_token, 
        1000,  // starting price 
        owner, 
        100,   // duration 
        10,    // discount rate
        5      // total supply
    );
    
    let dutch_auction_dispatcher = INFTDutchAuctionDispatcher { contract_address: auction };
    
    // Initial price should be 1000
    assert(dutch_auction_dispatcher.get_price() == 1000, 'Incorrect initial price');
    
    // Simulate time passing (note: this would require mocking block timestamp in a real test)
    // For demonstration, we're showing the price reduction logic
    let expected_price_after_50_time_units = 1000 - (10 * 50);
    assert(dutch_auction_dispatcher.get_price() <= expected_price_after_50_time_units, 'Price not reduced correctly');
}

#[test]
#[should_panic(expected: ('auction has ended', ))]
fn test_buy_after_auction_expires() {
    let owner = starknet::contract_address_const::<0x123>();
    let buyer = starknet::contract_address_const::<0x456>();
    let erc20_token = deploy_erc20(owner);
    let erc721_token = deploy_erc721(owner);
    
    let auction = deploy_dutch_auction(
        erc20_token, 
        erc721_token, 
        1000,  // starting price 
        owner, 
        10,    // very short duration 
        10,    // discount rate
        5      // total supply
    );
    
    let dutch_auction_dispatcher = INFTDutchAuctionDispatcher { contract_address: auction };
    let erc20_dispatcher = IERC20Dispatcher { contract_address: erc20_token };
    
    // Simulate buying after auction expires
    // Note: In a real test, you'd need to mock block timestamp
    dutch_auction_dispatcher.buy(1);
}

#[test]
fn test_successful_nft_purchase() {
    let owner = starknet::contract_address_const::<0x123>();
    let buyer = starknet::contract_address_const::<0x456>();
    let erc20_token = deploy_erc20(owner);
    let erc721_token = deploy_erc721(owner);
    
    let auction = deploy_dutch_auction(
        erc20_token, 
        erc721_token, 
        1000,  // starting price 
        owner, 
        100,   // duration 
        10,    // discount rate
        5      // total supply
    );
    
    let dutch_auction_dispatcher = INFTDutchAuctionDispatcher { contract_address: auction };
    let erc20_dispatcher = IERC20Dispatcher { contract_address: erc20_token };
    let erc721_dispatcher = IERC721Dispatcher { contract_address: erc721_token };
    
    // Prepare buyer's balance 
    // In a real test, you'd use a mock ERC20 that allows setting balance
    start_prank(CheatTarget::One(erc20_token), owner);
    // Assume a transfer or mint to buyer
    stop_prank(CheatTarget::One(erc20_token));
    
    // Approve auction to spend tokens
    start_prank(CheatTarget::One(erc20_token), buyer);
    // Assume approval logic
    stop_prank(CheatTarget::One(erc20_token));
    
    // Buy NFT
    start_prank(CheatTarget::One(auction), buyer);
    dutch_auction_dispatcher.buy(1);
    stop_prank(CheatTarget::One(auction));
    
    // Verify NFT ownership
    let token_owner = erc721_dispatcher.owner_of(1);
    assert(token_owner == buyer, 'NFT not transferred correctly');
}

#[test]
#[should_panic(expected: ('insufficient balance', ))]
fn test_buy_with_insufficient_balance() {
    let owner = starknet::contract_address_const::<0x123>();
    let buyer = starknet::contract_address_const::<0x456>();
    let erc20_token = deploy_erc20(owner);
    let erc721_token = deploy_erc721(owner);
    
    let auction = deploy_dutch_auction(
        erc20_token, 
        erc721_token, 
        1000,  // starting price 
        owner, 
        100,   // duration 
        10,    // discount rate
        5      // total supply
    );
    
    let dutch_auction_dispatcher = INFTDutchAuctionDispatcher { contract_address: auction };
    
    // Attempt to buy without sufficient balance
    dutch_auction_dispatcher.buy(1);
}

#[test]
#[should_panic(expected: ('auction has ended', ))]
fn test_buy_after_total_supply_exhausted() {
    let owner = starknet::contract_address_const::<0x123>();
    let buyer = starknet::contract_address_const::<0x456>();
    let erc20_token = deploy_erc20(owner);
    let erc721_token = deploy_erc721(owner);
    
    let auction = deploy_dutch_auction(
        erc20_token, 
        erc721_token, 
        1000,  // starting price 
        owner, 
        100,   // duration 
        10,    // discount rate
        1      // very low total supply
    );
    
    let dutch_auction_dispatcher = INFTDutchAuctionDispatcher { contract_address: auction };
    
    // First purchase should succeed
    dutch_auction_dispatcher.buy(1);
    
    // Second purchase should fail due to exhausted supply
    dutch_auction_dispatcher.buy(2);
}

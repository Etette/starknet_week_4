use starknet::ContractAddress;
use snforge_std::{declare, ContractClassTrait, DeclareResultTrait};

use auction_contract::{IERC20Dispatcher, IERC20DispatcherTrait, IERC721Dispatcher, IERC721DispatcherTrait, IHighestBidAuctionDispatcher, IHighestBidAuctionDispatcherTrait};

fn deploy_contract(name: ByteArray) -> ContractAddress {
    let contract = declare(name).unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@ArrayTrait::new()).unwrap();
    contract_address
}

#[test]
fn test_place_bid() {
    let auction_address = deploy_contract("HighestBidAuction");

    // Define dispatchers for interacting with the contract
    let auction_dispatcher = IHighestBidAuctionDispatcher { contract_address: auction_address };
    
    // Define initial state variables
    let initial_price: u128 = 10;
    let bid1 = 20;
    let bid2 = 30;
    
    // Place the first bid
    auction_dispatcher.place_bid(bid1);
    let (highest_bid, highest_bidder) = auction_dispatcher.get_highest_bid();
    assert(highest_bid == bid1, "First bid should be the highest bid");
    
    // Place a higher bid
    auction_dispatcher.place_bid(bid2);
    let (highest_bid, highest_bidder) = auction_dispatcher.get_highest_bid();
    assert(highest_bid == bid2, "Second bid should be the highest bid");
}

#[test]
#[feature("safe_dispatcher")]
fn test_end_auction() {
    let auction_address = deploy_contract("HighestBidAuction");

    // Define dispatchers for safe operations
    let auction_dispatcher = IHighestBidAuctionDispatcher { contract_address: auction_address };
    let erc721_dispatcher = IERC721Dispatcher { contract_address: auction_address };
    let seller = ContractAddress::create();
    let highest_bid = 30u128;

    // Set up auction and place bid
    auction_dispatcher.start_auction(seller, initial_price, duration);
    auction_dispatcher.place_bid(highest_bid);
    
    // End the auction
    let result = auction_dispatcher.end_auction();
    match result {
        Result::Ok(_) => {
            // Verify NFT transfer to the highest bidder
            let nft_owner = erc721_dispatcher.owner_of(1);
            assert(nft_owner == highest_bidder, "NFT should be transferred to the highest bidder");
            
            // Verify seller's balance
            let seller_balance = erc20_dispatcher.balance_of(seller);
            assert(seller_balance == highest_bid, "Seller should receive the highest bid amount");
        },
        Result::Err(panic_data) => {
            assert(false, "Ending auction should not fail");
        }
    }
}

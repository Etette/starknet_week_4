use starknet::ContractAddress;
 
#[starknet::interface]
pub trait IERC20<TContractState> {
    fn get_name(self: @TContractState) -> felt252;
    fn get_symbol(self: @TContractState) -> felt252;
    fn get_decimals(self: @TContractState) -> u8;
    fn get_total_supply(self: @TContractState) -> felt252;
    fn balance_of(self: @TContractState, account: ContractAddress) -> felt252;
    fn allowance(
        self: @TContractState, owner: ContractAddress, spender: ContractAddress
    ) -> felt252;
    fn transfer(ref self: TContractState, recipient: ContractAddress, amount: felt252);
    fn transfer_from(
        ref self: TContractState,
        sender: ContractAddress,
        recipient: ContractAddress,
        amount: felt252
    );
    fn approve(ref self: TContractState, spender: ContractAddress, amount: felt252);
    fn increase_allowance(ref self: TContractState, spender: ContractAddress, added_value: felt252);
    fn decrease_allowance(
        ref self: TContractState, spender: ContractAddress, subtracted_value: felt252
    );
}
 
#[starknet::interface]
trait IERC721<TContractState> {
    fn get_name(self: @TContractState) -> felt252;
    fn get_symbol(self: @TContractState) -> felt252;
    fn get_token_uri(self: @TContractState, token_id: u256) -> felt252;
    fn balance_of(self: @TContractState, account: ContractAddress) -> u256;
    fn owner_of(self: @TContractState, token_id: u256) -> ContractAddress;
    fn get_approved(self: @TContractState, token_id: u256) -> ContractAddress;
    fn is_approved_for_all(
        self: @TContractState, owner: ContractAddress, operator: ContractAddress
    ) -> bool;
    fn approve(ref self: TContractState, to: ContractAddress, token_id: u256);
    fn set_approval_for_all(ref self: TContractState, operator: ContractAddress, approved: bool);
    fn transfer_from(
        ref self: TContractState, from: ContractAddress, to: ContractAddress, token_id: u256
    );
    fn mint(ref self: TContractState, to: ContractAddress, token_id: u256);
}
 
#[starknet::interface]
pub trait INFTDutchAuction<TContractState> {
    fn buy(ref self: TContractState, token_id: u256);
    fn get_price(self: @TContractState) -> u64;
}
 
#[starknet::contract]
pub mod NFTDutchAuction {
    use super::{IERC20Dispatcher, IERC20DispatcherTrait, IERC721Dispatcher, IERC721DispatcherTrait};
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
 
    #[storage]
    struct Storage {
        erc20_token: ContractAddress,
        erc721_token: ContractAddress,
        starting_price: u64,
        seller: ContractAddress,
        duration: u64,
        discount_rate: u64,
        start_at: u64,
        expires_at: u64,
        purchase_count: u128,
        total_supply: u128
    }
 
    mod Errors {
        pub const AUCTION_ENDED: felt252 = 'auction has ended';
        pub const LOW_STARTING_PRICE: felt252 = 'low starting price';
        pub const INSUFFICIENT_BALANCE: felt252 = 'insufficient balance';
    }
 
    #[constructor]
    fn constructor(
        ref self: ContractState,
        erc20_token: ContractAddress,
        erc721_token: ContractAddress,
        starting_price: u64,
        seller: ContractAddress,
        duration: u64,
        discount_rate: u64,
        total_supply: u128
    ) {
        assert(starting_price >= discount_rate * duration, Errors::LOW_STARTING_PRICE);
 
        self.erc20_token.write(erc20_token);
        self.erc721_token.write(erc721_token);
        self.starting_price.write(starting_price);
        self.seller.write(seller);
        self.duration.write(duration);
        self.discount_rate.write(discount_rate);
        self.start_at.write(get_block_timestamp());
        self.expires_at.write(get_block_timestamp() + duration * 1000);
        self.total_supply.write(total_supply);
    }
 
    #[abi(embed_v0)]
    impl NFTDutchAuction of super::INFTDutchAuction<ContractState> {
        fn get_price(self: @ContractState) -> u64 {
            let time_elapsed = (get_block_timestamp() - self.start_at.read())
                / 1000; // Ignore milliseconds
            let discount = self.discount_rate.read() * time_elapsed;
            self.starting_price.read() - discount
        }
 
        fn buy(ref self: ContractState, token_id: u256) {
            // Check duration
            assert(get_block_timestamp() < self.expires_at.read(), Errors::AUCTION_ENDED);
            // Check total supply
            assert(self.purchase_count.read() < self.total_supply.read(), Errors::AUCTION_ENDED);
 
            let erc20_dispatcher = IERC20Dispatcher { contract_address: self.erc20_token.read() };
            let erc721_dispatcher = IERC721Dispatcher {
                contract_address: self.erc721_token.read()
            };
 
            let caller = get_caller_address();
            // Get NFT price
            let price: u256 = self.get_price().into();
            let buyer_balance: u256 = erc20_dispatcher.balance_of(caller).into();
            // Ensure buyer has enough token for payment
            assert(buyer_balance >= price, Errors::INSUFFICIENT_BALANCE);
            // Transfer payment token from buyer to seller
            erc20_dispatcher.transfer_from(caller, self.seller.read(), price.try_into().unwrap());
            // Mint token to buyer's address
            erc721_dispatcher.mint(caller, token_id);
            // Increase purchase count
            self.purchase_count.write(self.purchase_count.read() + 1);
        }
    }
}

// use starknet::ContractAddress;

// #[starknet::interface]
// pub trait IERC20<TContractState> {
//     fn transfer_from(
//         ref self: TContractState,
//         sender: ContractAddress,
//         recipient: ContractAddress,
//         amount: felt252
//     );
//     fn balance_of(self: @TContractState, account: ContractAddress) -> felt252;
// }

// #[starknet::interface]
// pub trait IERC721<TContractState> {
//     fn transfer_from(
//         ref self: TContractState, from: ContractAddress, to: ContractAddress, token_id: u256
//     );
//     fn owner_of(self: @TContractState, token_id: u256) -> ContractAddress;
// }

// #[starknet::interface]
// pub trait INFTDutchAuction<TContractState> {
//     fn place_bid(ref self: TContractState, bid_amount: felt252);
//     fn end_auction(ref self: TContractState);
//     fn get_highest_bid(self: @TContractState) -> (felt252, ContractAddress);
// }

// #[starknet::contract]
// pub mod NFTBiddingAuction {
//     use super::{IERC20Dispatcher, IERC20DispatcherTrait, IERC721Dispatcher, IERC721DispatcherTrait};
//     use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
//     use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};

//     #[storage]
//     struct Storage {
//         erc20_token: ContractAddress,
//         erc721_token: ContractAddress,
//         nft_token_id: u256,
//         starting_price: felt252,
//         seller: ContractAddress,
//         duration: u64,
//         start_at: u64,
//         highest_bid: felt252,
//         highest_bidder: ContractAddress,
//         auction_ended: bool,
//     }

//     mod Errors {
//         pub const AUCTION_ENDED: felt252 = 'auction has ended';
//         pub const LOW_BID: felt252 = 'bid is too low';
//         pub const NOT_ENDED: felt252 = 'auction has not ended yet';
//     }

//     #[constructor]
//     fn constructor(
//         ref self: ContractState,
//         erc20_token: ContractAddress,
//         erc721_token: ContractAddress,
//         nft_token_id: u256,
//         starting_price: felt252,
//         seller: ContractAddress,
//         duration: u64
//     ) {
//         self.erc20_token.write(erc20_token);
//         self.erc721_token.write(erc721_token);
//         self.nft_token_id.write(nft_token_id);
//         self.starting_price.write(starting_price);
//         self.seller.write(seller);
//         self.duration.write(duration);
//         self.start_at.write(get_block_timestamp());
//         self.highest_bid.write(starting_price);
//         self.highest_bidder.write(seller); // Initially, the seller holds the highest bid
//         self.auction_ended.write(false);
//     }

//     #[abi(embed_v0)]
//     impl NFTBiddingAuction of super::INFTDutchAuction {
//         fn place_bid(ref self: ContractState, bid_amount: felt252) {
//             // Ensure auction is active
//             assert(!self.auction_ended.read(), Errors::AUCTION_ENDED);
//             assert(get_block_timestamp() < self.start_at.read() + self.duration.read(), Errors::AUCTION_ENDED);

//             let caller = get_caller_address();

//             // Check if the new bid is higher than the current highest bid
//             assert(bid_amount > self.highest_bid.read(), Errors::LOW_BID);

//             let erc20_dispatcher = IERC20Dispatcher { contract_address: self.erc20_token.read() };

//             // Ensure caller has sufficient balance for the bid
//             let caller_balance: felt252 = erc20_dispatcher.balance_of(caller);
//             assert(caller_balance >= bid_amount, Errors::LOW_BID);

//             // Update highest bid and bidder
//             self.highest_bid.write(bid_amount);
//             self.highest_bidder.write(caller);
//         }

//         fn end_auction(ref self: ContractState) {
//             // Ensure auction is over
//             assert(get_block_timestamp() >= self.start_at.read() + self.duration.read(), Errors::NOT_ENDED);
//             assert(!self.auction_ended.read(), Errors::AUCTION_ENDED);

//             let erc20_dispatcher = IERC20Dispatcher { contract_address: self.erc20_token.read() };
//             let erc721_dispatcher = IERC721Dispatcher { contract_address: self.erc721_token.read() };

//             // Transfer highest bid amount to the seller
//             erc20_dispatcher.transfer_from(self.highest_bidder.read(), self.seller.read(), self.highest_bid.read());

//             // Transfer NFT to the highest bidder
//             erc721_dispatcher.transfer_from(self.seller.read(), self.highest_bidder.read(), self.nft_token_id.read());

//             // Mark auction as ended
//             self.auction_ended.write(true);
//         }

//         fn get_highest_bid(self: @ContractState) -> (felt252, ContractAddress) {
//             (self.highest_bid.read(), self.highest_bidder.read())
//         }
//     }
// }

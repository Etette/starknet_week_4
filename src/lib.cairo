// use starknet::ContractAddress;

// #[starknet::interface]
// pub trait IAuction<TContractState> {
//     fn place_bid(ref self: TContractState, bid_amount: felt252) -> Result<(), felt252>;
//     fn end_auction(ref self: TContractState) -> Result<(), felt252>;
//     fn get_auction_state(self: @TContractState) -> (felt252, felt252, bool);
//     fn get_caller(self: @TContractState) -> ContractAddress;
// }

// #[starknet::contract]
// mod Auction {
//     use starknet::ContractAddress;

//     #[storage]
//     struct Storage {
//         owner: ContractAddress,
//         nft_id: felt252,
//         highest_bidder: ContractAddress,
//         highest_bid: felt252,
//         is_auction_active: bool,
//     }

//     #[constructor]
//     fn constructor(ref self: ContractState, nft_id: felt252) {
//         self.owner.write(self.get_caller());
//         self.nft_id.write(nft_id);
//         self.is_auction_active.write(true);
//         self.highest_bid.write(0);
//     }

//     #[abi(embed_v0)]
//     impl AuctionImpl of super::IAuction<ContractState> {
        
       
//         fn place_bid(ref self: ContractState, bid_amount: felt252) -> Result<(), felt252> {
//             let current_highest_bid = self.highest_bid.read();
//             assert(self.is_auction_active.read() == true, "Auction is not active.");
//             assert(bid_amount > current_highest_bid, "Bid amount is too low.");

//             // Update highest bid and bidder
//             self.highest_bid.write(bid_amount);
//             self.highest_bidder.write(self.get_caller());

//             Ok(())
//         }

//         fn end_auction(ref self: ContractState) -> Result<(), felt252> {
//             assert(self.get_caller() == self.owner.read(), "Only the owner can end the auction.");
//             self.is_auction_active.write(false);
//             Ok(())
//         }

//         fn get_auction_state(self: @ContractState) -> (felt252, felt252, bool) {
//             (
//                 self.highest_bidder.read().to_felt252(),  // convert address to felt252 if necessary
//                 self.highest_bid.read(),
//                 self.is_auction_active.read()
//             )
//         }

//         fn get_caller(self: @ContractState) -> ContractAddress {
//             return self.owner.read();
//         }

//     }
// }
mod auction;

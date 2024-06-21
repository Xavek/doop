use starknet::ContractAddress;

#[starknet::interface]
pub trait IPool<TContractState> {
    fn deposit(ref self: TContractState, token_address: ContractAddress, amount: u256) -> bool;
    fn withdraw(ref self: TContractState, id: felt252, amount: u256) -> bool;
    fn add_or_update_token_address(
        ref self: TContractState, token_address: ContractAddress
    ) -> bool;
    fn inc_deposit(ref self: TContractState, id: felt252, amount: u256) -> bool;
}

#[starknet::interface]
pub trait IERC20<TContractState> {
    fn balanceOf(self: @TContractState, account: ContractAddress) -> u256;
    fn allowance(self: @TContractState, owner: ContractAddress, spender: ContractAddress) -> u256;
    fn transfer(ref self: TContractState, recipient: ContractAddress, amount: u256) -> bool;
    fn transferFrom(
        ref self: TContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256
    ) -> bool;
    fn approve(ref self: TContractState, spender: ContractAddress, amount: u256) -> bool;
}

#[starknet::contract]
pub mod Pool {
    use core::hash::HashStateTrait;
    use core::hash::HashStateExTrait;
    use super::{IPool, ContractAddress, IERC20DispatcherTrait, IERC20Dispatcher};
    use starknet::{
        get_caller_address, get_contract_address, storage_access::StorageBaseAddress, ClassHash
    };
    use core::poseidon::{PoseidonTrait};

    #[derive(Drop, Serde, starknet::Store)]
    pub struct DepositInfo {
        pub token_address: ContractAddress,
        pub owner: ContractAddress,
        pub amount: u256,
        pub is_deposit: bool
    }

    #[storage]
    struct Storage {
        deposits: LegacyMap::<felt252, DepositInfo>,
        personal_nonce: LegacyMap::<ContractAddress, u64>,
    }


    #[abi(embed_v0)]
    impl PoolImpl of IPool<ContractState> {
        fn deposit(ref self: ContractState, token_address: ContractAddress, amount: u256) -> bool {
            let caller = get_caller_address();
            let current_nonce = self.personal_nonce.read(caller);
            if (current_nonce > 0) {
                self._do_erc20_transfer(token_address, caller, amount);
                let unique_id = self.get_repeat_or_unique_id(caller, current_nonce + 1);
                self
                    .deposits
                    .write(
                        unique_id,
                        DepositInfo {
                            token_address: token_address,
                            owner: caller,
                            amount: amount,
                            is_deposit: true
                        }
                    );
                self.personal_nonce.write(caller, current_nonce + 1);
            } else {
                self._do_erc20_transfer(token_address, caller, amount);
                let unique_id = self.get_repeat_or_unique_id(caller, 1);
                self
                    .deposits
                    .write(
                        unique_id,
                        DepositInfo {
                            token_address: token_address,
                            owner: caller,
                            amount: amount,
                            is_deposit: true
                        }
                    );
                self.personal_nonce.write(caller, 1);
            }
            true
        }

        fn withdraw(ref self: ContractState, id: felt252, amount: u256) -> bool {
            let caller = get_caller_address();
            true
        }

        fn add_or_update_token_address(
            ref self: ContractState, token_address: ContractAddress
        ) -> bool {
            true
        }

        fn inc_deposit(ref self: ContractState, id: felt252, amount: u256) -> bool {
            let caller = get_caller_address();
            true
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn get_repeat_or_unique_id(
            ref self: ContractState, address: ContractAddress, unique_nonce: u64
        ) -> felt252 {
            PoseidonTrait::new().update_with(address).update_with(unique_nonce).finalize()
        }

        fn _do_erc20_transfer(
            ref self: ContractState,
            token_address: ContractAddress,
            caller: ContractAddress,
            amount: u256
        ) {
            let amount_into: u256 = amount.into();
            let transfer_flag: bool = IERC20Dispatcher { contract_address: token_address }
                .transferFrom(caller, get_contract_address(), amount_into);
            assert(transfer_flag, 'ERC20_TRANSFER_FAIL')
        }
    }
}

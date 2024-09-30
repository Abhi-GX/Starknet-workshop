
#[starknet::interface]
pub trait ICounter<TContractState> {
    fn get_counter(self: @TContractState) -> u32;
    fn increase_counter(ref self: TContractState);
}

#[starknet::contract]
mod counter_contract {
    use super::ICounter;
    use kill_switch::{IKillSwitchDispatcher, IKillSwitchDispatcherTrait};
    use starknet::{ContractAddress, get_caller_address};
    use openzeppelin::access::ownable::OwnableComponent;
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        counter: u32,
        kill_switch: ContractAddress,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        CounterIncreased: CounterIncreased,
        #[flat]
        OwnableEvent: OwnableComponent::Event
    }

    #[derive(Drop, starknet::Event)]
    struct CounterIncreased {
        #[key]
        value: u32,
    }
    //step-1 intial declaration
    #[constructor]
    fn constructor(ref self: ContractState, initial_value: u32, kill_switch_address: ContractAddress,initial_owner: ContractAddress) {
        self.ownable.initializer(initial_owner);
        self.counter.write(initial_value);
        self.kill_switch.write(kill_switch_address);
    }

    #[abi(embed_v0)]
    impl counter_contract of super::ICounter<ContractState> {
        fn get_counter(self: @ContractState) -> u32 {
            self.counter.read()
        }
        fn increase_counter(ref self: ContractState) {
            self.ownable.assert_only_owner();
            let kill_switch_address = self.kill_switch.read();
            let kill_switch = IKillSwitchDispatcher { contract_address: kill_switch_address };
            assert!(!kill_switch.is_active(), "Kill Switch is active");
            
            let current_value = self.counter.read();
            let new_value = current_value + 1;

            self.counter.write(new_value);
            self.emit(Event::CounterIncreased(CounterIncreased { value: new_value }));
        }
    }
}
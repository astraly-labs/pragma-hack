use starknet::ContractAddress;

#[starknet::interface]
trait HackTemplateABI<TContractState> {
    fn initializer(
        ref self: TContractState, pragma_contract: ContractAddress, summary_stats: ContractAddress
    );
    fn check_eth_threshold(self: @TContractState, threshold: u128) -> bool;
    fn get_asset_price(self: @TContractState, asset_id: felt252) -> felt252;
    fn realized_volatility(self: @TContractState) -> felt252;
}


#[starknet::contract]
mod HackTemplate {
    use super::{ContractAddress, HackTemplateABI};
    use array::{ArrayTrait, SpanTrait};
    use traits::{Into, TryInto};
    use hack_template::interfaces::{
        cairo_0::pragma::{
            PragmaOracleDispatcher, PragmaOracleDispatcherTrait, SummaryStatsDispatcher,
            SummaryStatsDispatcherTrait
        },
    };

    use alexandria_math::pow;
    use starknet::get_block_timestamp;
    use option::OptionTrait;

    #[storage]
    struct Storage {
        pragma_contract: ContractAddress,
        summary_stats: ContractAddress,
    }

    #[external(v0)]
    impl HackTemplateABIImpl of HackTemplateABI<ContractState> {
        fn initializer(
            ref self: ContractState,
            pragma_contract: ContractAddress,
            summary_stats: ContractAddress
        ) {
            if self.pragma_contract.read().into() == 0 {
                self.pragma_contract.write(pragma_contract);
            }
            if self.summary_stats.read().into() == 0 {
                self.summary_stats.write(summary_stats);
            }
        }

        fn check_eth_threshold(self: @ContractState, threshold: u128) -> bool {
            // Retrieve the oracle dispatcher
            let oracle_dispatcher = PragmaOracleDispatcher {
                contract_address: self.pragma_contract.read()
            };

            // Call the Oracle contract
            let (price, decimals, last_updated_timestamp, num_sources_aggregated) =
                oracle_dispatcher
                .get_spot_median('ETH/USD');

            // We only care about DEFILLAMA and COINBASE
            let mut sources = ArrayTrait::new();
            sources.append('DEFILLAMA');
            sources.append('COINBASE');
            let (price, decimals, last_updated_timestamp, num_sources_aggregated) =
                oracle_dispatcher
                .get_spot_for_sources('BTC/USD', 0, sources);

            // Normalize based on number of decimals
            let decimals: u128 = decimals.try_into().unwrap();
            let multiplier: u128 = pow(10, decimals);

            // Shift the threshold by the multiplier
            let shifted_threshold: u128 = threshold * multiplier;

            // Some annoying type conversions that will disappear with future compiler versions
            let price: u256 = price.into();
            let shifted_threshold: felt252 = shifted_threshold.into();
            let shifted_threshold: u256 = shifted_threshold.into();

            return shifted_threshold <= price;
        }
        fn get_asset_price(self: @ContractState, asset_id: felt252) -> felt252 {
            // Retrieve the oracle dispatcher
            let oracle_dispatcher = PragmaOracleDispatcher {
                contract_address: self.pragma_contract.read()
            };

            // Call the Oracle contract
            let (price, decimals, last_updated_timestamp, num_sources_aggregated) =
                oracle_dispatcher
                .get_spot_median(asset_id);

            return price;
        }

        fn realized_volatility(self: @ContractState) -> felt252 {
            let oracle_dispatcher = SummaryStatsDispatcher {
                contract_address: self.summary_stats.read()
            };

            let key = 'ETH/USD';
            let timestamp = starknet::get_block_timestamp();

            let start = timestamp - 259200000; // 1 month ago
            let end = timestamp; // now

            let num_samples = 200; // Maximum 200 because of Cairo Steps limit

            let volatility = oracle_dispatcher
                .calculate_volatility(key, start.into(), end.into(), num_samples);

            let mean = oracle_dispatcher.calculate_mean(key, start.into(), end.into());

            volatility
        }
    }
}

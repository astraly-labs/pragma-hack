use starknet::ContractAddress;

#[starknet::interface]
trait HackTemplateABI<TContractState> {
    fn initializer(
        ref self: TContractState, pragma_contract: ContractAddress, summary_stats: ContractAddress
    );
    fn check_eth_threshold(self: @TContractState, threshold: u32) -> bool;
    fn get_asset_price(self: @TContractState, asset_id: felt252) -> u128;
    fn realized_volatility(self: @TContractState) -> (u128, u32);
}


#[starknet::contract]
mod HackTemplate {
    use super::{ContractAddress, HackTemplateABI};
    use array::{ArrayTrait, SpanTrait};
    use traits::{Into, TryInto};
    use hack_template::interfaces::{
        cairo_1::pragma::{
            IPragmaABIDispatcher, IPragmaABIDispatcherTrait, ISummaryStatsABIDispatcher,
            ISummaryStatsABIDispatcherTrait, DataType, AggregationMode, PragmaPricesResponse
        },
    };

    use alexandria_math::pow;
    use starknet::get_block_timestamp;
    use option::OptionTrait;
    const ETH_USD: felt252 = 'ETH/USD';
    const BTC_USD: felt252 = 'BTC/USD';
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

        fn check_eth_threshold(self: @ContractState, threshold: u32) -> bool {
            // Retrieve the oracle dispatcher
            let oracle_dispatcher = IPragmaABIDispatcher {
                contract_address: self.pragma_contract.read()
            };

            // Call the Oracle contract
            let output: PragmaPricesResponse = oracle_dispatcher
                .get_data_median(DataType::SpotEntry(ETH_USD));

            // We only care about DEFILLAMA and COINBASE
            let defillama: felt252 = 'DEFILLAMA';
            let coinbase: felt252 = 'COINBASE';
            let mut sources = array![defillama, coinbase];
            let output: PragmaPricesResponse = oracle_dispatcher
                .get_data_for_sources(
                    DataType::SpotEntry(BTC_USD), AggregationMode::Median(()), sources.span()
                );

            // Normalize based on number of decimals
            let decimals: u128 = output.decimals.into();
            let multiplier: u128 = pow(10, decimals);

            // Shift the threshold by the multiplier
            let shifted_threshold: u128 = threshold.into() * multiplier;

            return shifted_threshold <= output.price;
        }
        fn get_asset_price(self: @ContractState, asset_id: felt252) -> u128 {
            // Retrieve the oracle dispatcher
            let oracle_dispatcher = IPragmaABIDispatcher {
                contract_address: self.pragma_contract.read()
            };

            // Call the Oracle contract, for a spot entry
            let output: PragmaPricesResponse = oracle_dispatcher
                .get_data_median(DataType::SpotEntry(asset_id));

            return output.price;
        }

        fn realized_volatility(self: @ContractState) -> (u128, u32) {
            let oracle_dispatcher = ISummaryStatsABIDispatcher {
                contract_address: self.summary_stats.read()
            };

            let key = 'ETH/USD';
            let timestamp = starknet::get_block_timestamp();

            let start = timestamp - 259200000; // 1 month ago
            let end = timestamp; // now

            let num_samples = 200; // Maximum 200 because of Cairo Steps limit

            let (volatility, decimals) = oracle_dispatcher
                .calculate_volatility(
                    DataType::SpotEntry(key),
                    start.into(),
                    end.into(),
                    num_samples,
                    AggregationMode::Median(())
                );

            let (mean, mean_decimals) = oracle_dispatcher
                .calculate_mean(
                    DataType::SpotEntry(key), start.into(), end.into(), AggregationMode::Median(())
                );

            (volatility, decimals)
        }
    }
}

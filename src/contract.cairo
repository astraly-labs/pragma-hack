#[contract]
mod HackTemplate {
    use starknet::ContractAddress;
    use traits::{Into, TryInto};
    use hack_template::interfaces::{
        pragma::{PragmaOracleDispatcher, PragmaOracleDispatcherTrait},
    };
    use alexandria_math::math::pow;

    struct Storage {
        pragma_contract: ContractAddress, 
    }

    #[external]
    fn initializer(pragma_contract: ContractAddress, naming_contract: ContractAddress) {
        if pragma_contract::read().into() == 0 {
            pragma_contract::write(pragma_contract);
        }
    }

    #[external]
    fn check_eth_threshold(threshold: felt252) -> felt252 {
        // Retrieve the oracle dispatcher
        let oracle_dispatcher = PragmaOracleDispatcher {
            contract_address: pragma_contract::read()
        };

        // Call the Oracle contract
        let (price, decimals, last_updated_timestamp, num_sources_aggregated) = oracle_dispatcher
            .get_spot_median('ETH/USD');

        // Normalize based on number of decimals
        let multiplier = pow(10, decimals);

        // Shift the threshold by the multiplier
        let shifted_threshold = threshold * multiplier;

        return shifted_threshold <= price;
    }

    #[view]
    fn get_asset_price(asset_id: felt252) -> felt252 {
        // Retrieve the oracle dispatcher
        let oracle_dispatcher = PragmaOracleDispatcher {
            contract_address: pragma_contract::read()
        };

        // Call the Oracle contract
        let (price, decimals, last_updated_timestamp, num_sources_aggregated) = oracle_dispatcher
            .get_spot_median(asset_id);

        return price;
    }
}

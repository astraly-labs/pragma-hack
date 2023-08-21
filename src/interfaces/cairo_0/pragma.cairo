#[derive(Serde, Drop)]
struct BaseEntry {
    timestamp: felt252, // Timestamp of the most recent update, UTC epoch
    source: felt252, // UTF-8 encoded uppercased string, e.g. "GEMINI"
    publisher: felt252, // UTF-8 encoded uppercased string, e.g. "CONSENSYS"
// Publisher of the data (usually the source, but occasionally a third party)
}

#[derive(Serde, Drop)]
struct SpotEntry {
    base: BaseEntry,
    pair_id: felt252, // UTF-8 encoded uppercased string, e.g. "ETH/USD"
    price: felt252, // Price shifted to the left by decimals
    volume: felt252, // Volume aggregated into this market price
}

#[derive(Serde, Drop)]
struct Checkpoint {
    timestamp: felt252,
    value: felt252,
    aggregation_mode: felt252,
    num_sources_aggregated: felt252,
}

#[derive(Serde, Drop)]
struct EmpiricPricesResponse {
    price: felt252,
    decimals: felt252,
    last_updated_timestamp: felt252,
    num_sources_aggregated: felt252,
}

#[derive(Serde, Drop)]
struct FutureEntry {
    base: BaseEntry,
    pair_id: felt252,
    price: felt252,
    expiry_timestamp: felt252,
}

#[derive(Serde, Drop)]
struct GenericEntry {
    base: BaseEntry,
    key: felt252,
    value: felt252,
}

const MEDIAN: felt252 = 'MEDIAN';

#[starknet::interface]
trait PragmaOracle<TContractState> {
    fn get_spot_median(
        self: @TContractState, pair_id: felt252
    ) -> (felt252, felt252, felt252, felt252);

    fn get_spot(
        self: @TContractState, pair_id: felt252, aggregation_mode: felt252
    ) -> (felt252, felt252, felt252, felt252);

    fn get_spot_median_multi(
        self: @TContractState, pair_ids_len: felt252, pair_ids: felt252, idx: felt252
    ) -> Array<EmpiricPricesResponse>;

    fn get_spot_with_USD_hop(
        self: @TContractState,
        base_currency_id: felt252,
        quote_currency_id: felt252,
        aggregation_mode: felt252
    ) -> (felt252, felt252, felt252, felt252);

    fn get_spot_with_hop(
        self: @TContractState,
        currency_ids_len: felt252,
        currency_ids: felt252,
        aggregation_mode: felt252
    ) -> (felt252, felt252, felt252, felt252);

    fn get_spot_median_for_sources(
        self: @TContractState, pair_id: felt252, sources: Array<felt252>
    ) -> (felt252, felt252, felt252, felt252);

    fn get_spot_for_sources(
        self: @TContractState, pair_id: felt252, aggregation_mode: felt252, sources: Array<felt252>
    ) -> (felt252, felt252, felt252, felt252);

    fn get_futures_for_sources(
        self: @TContractState, pair_id: felt252, expiry_timestamp: felt252, sources: Array<felt252>
    ) -> (felt252, felt252, felt252, felt252);

    fn get_spot_entry(self: @TContractState, pair_id: felt252, source: felt252) -> SpotEntry;

    fn get_spot_entries(
        self: @TContractState, pair_id: felt252, sources: Array<felt252>
    ) -> Array<SpotEntry>;

    fn get_spot_entries_for_sources(
        self: @TContractState, pair_id: felt252, sources: Array<felt252>
    ) -> Array<SpotEntry>;

    fn get_spot_decimals(self: @TContractState, pair_id: felt252) -> felt252;

    fn get_future_entry(
        self: @TContractState, pair_id: felt252, expiry_timestamp: felt252, source: felt252
    ) -> FutureEntry;

    fn get_future_entries(
        self: @TContractState, pair_id: felt252, expiry_timestamp: felt252, sources: Array<felt252>
    ) -> Array<FutureEntry>;

    fn get_future_entries_for_sources(
        self: @TContractState, pair_id: felt252, expiry_timestamp: felt252, sources: Array<felt252>
    ) -> Array<FutureEntry>;

    fn get_last_spot_checkpoint_before(
        self: @TContractState, pair_id: felt252, timestamp: felt252
    ) -> (Checkpoint, felt252);

    fn get_entry(self: @TContractState, key: felt252, source: felt252) -> GenericEntry;

    fn get_entries(self: @TContractState, key: felt252) -> Array<GenericEntry>;

    fn get_entries_for_sources(
        self: @TContractState, key: felt252, sources: Array<felt252>
    ) -> Array<GenericEntry>;
}

#[starknet::interface]
trait SummaryStats<TContractState> {
    fn calculate_mean(
        self: @TContractState, key: felt252, start: felt252, stop: felt252
    ) -> felt252;

    fn calculate_volatility(
        self: @TContractState, key: felt252, start: felt252, stop: felt252, num_samples: felt252
    ) -> felt252;
}

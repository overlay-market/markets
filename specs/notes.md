# Implementation Notes for OVL

### Protocol

The Overlay protocol offers users the ability to trade nearly any scalar, non-manipulable and unpredictable data stream. It recreates the dynamics of trading, but without the need for counterparties. It therefore completely solves the liquidity problems that occur in prediction markets (i.e. markets are so niche there is nobody trading), replacing them with an inflation problem.

The Overlay mechanism is simple: traders enter positions by locking up OVL tokens in long or short positions on various data streams offered by the protocol. Data streams are obtained via reliable oracles. When a trader exits that same position, the protocol dynamically mints/burns OVL based off of their net profit/loss for the trade. The contract then credits/removes OVL tokens from the trader's balance and adds/subtracts from the total existing supply of OVL.

Protocol revenues come from trading fees charged in OVL on each trade. Fees are sent to a community-governed treasury, with incentives for secondary market liquidity providers. This secondary market incentive creates a feedback loop to offer a reliable price feed for OVLETH on the Overlay trading platform, that traders can then use to hedge out OVL risk.

### OVL Token (ERC20)

1. Allows holders to participate in long/short trading of data streams

2. Gives holders governance stake in proposed data feeds and tuning of their risk parameters

3. Gives holders governance control over treasury: revenue from fees on each trade.

### OVL Position (ERC1155)

- Token representing a trader's position,  received upon locking up OVL in a trade on a data stream

- Unique identifiers are attrs of the position: Lock price, data feed name, long/short side, leverage

- Tradeable/transferrable on secondary markets given ERC1155 standard

### Hackathon (v0)

- Only focus on BTC and ETH streams (the UNI incentivized pools) Uniswap pools for WBTCETH ($488M in liquidity) and ETHUSDT ($396M in liquidity), as well as associated Chainlink BTCUSD, ETHUSD, High Gas feeds.

- Have OVLv0 as fixed amount distributed via first come first serve for alpha testers

**v1** will be yield farming for rest of the token distribution (90%).

#### Spec

- Emphasis on modularity. Feed and trading position contracts act as their own modular capsule. Governance adds these in pairs.

- **OVLToken (ERC20 Token):** Base token with public `mint()`, `burn()` functions through `AccessControl` privileges

- **OVLPosition (ERC1155 Token):** Positions as ERC1155 tokens allows for transfers on secondary markets

- Position contracts have admin access to OVL token contract for mint/burn functions

- Position contracts fetch prices from associated feed contract whenever updates to the position occur


![spec](OVL.svg)


```
// Base ERC20 OVL token
interface OVLToken {

  function mint(uint256 _amount) external;

  function burn(uint256 _amount) external;

}

// Position ERC1155 token
interface OVLPosition {

    IERC20 public token;

    struct Position {
       bool long;
       uint256 leverage;
       uint256 lockPrice;
    }

   function build(uint256 _amount, bool _long, uint256 _leverage) external;

   function buildAll(bool _long, uint256 _leverage) external;

   function unwind(uint256 _id, uint256 _amount) external;

   function unwindAll(uint256 _id) external;

   function liquidate(uint256 _id) external;

   function liquidatable() external returns (uint256[] memory);

}
```

### Revenue Model

Fees (in $OVL): 0.15% per trade, adjustable by governance on feed-by-feed basis

- 50% is burned
- 50% is sold for ETH via Uniswap through treasury

To incentivize OVLETH liquidity providers and governance contributors in perpetuity, take the 50% of the ETH to treasury and divide evenly between
- 50% (25% of total fees) to OVLETH LPs staking
- 50% (25% of total fees) to governance $OVL stakers that vote

Eventually lend out the locked OVL from positions for capital efficiency and additional revenue.

### Token Distribution

Three phases for initial token distribution (~ 10% to alpha testers, ~ 90% to yield farmers):
1. Token claim for alpha testers of trading mechanism (~ 10%)
2. Beta yield farming of $OVL with other Uniswap token pools: $SNXETH, $AAVEETH, $WBTCETH, etc.
3. Beta yield farming of more $OVL with seeded Uniswap $OVL/$ETH LP tokens


### Roadmap

1. Long/Short w corresponding tokens on launch (ETH x DeFi token pools & feeds)
2. Uniswap and Chainlink oracles for base pair feeds
3. Gas ⛽️ oracle (front-run resistant) w feed (Chainlink)
4. Leverage
5. More feeds
6. New stablecoin based off composition of derivs
7. Lending of Locked OVL positions (likely through Aave)
8. Expiries?

**(1, 2, 3) are good proof of concept (POC) for the hack. Include 4, maybe.**

# Implementation Notes for OVL

### Protocol

The Overlay protocol offers users the ability to trade nearly any scalar, non-manipulable and unpredictable data stream. It recreates the dynamics of trading, but without the need for counterparties. It therefore completely solves the liquidity problems that occur in prediction markets (i.e. markets are so niche there is nobody trading), replacing them with an inflation problem. This inflation problem is addressed by the protocol’s monetary policy.

The Overlay mechanism is simple: traders enter positions by locking up OVL tokens in long or short positions on various data streams offered by the protocol. Data streams are obtained via reliable oracles. When a trader exits that same position, the protocol dynamically mints/burns OVL based off of their net profit/loss for the trade. The contract then credits/removes OVL tokens from the trader's balance and adds/subtracts from the total existing supply of OVL.

Protocol revenues come from trading fees charged in OVL on each trade. Fees are sent to a community-governed treasury, with incentives for secondary market liquidity providers. This secondary market incentive creates a feedback loop to offer a reliable price feed for OVLETH on the Overlay trading platform, that traders can then use to hedge out OVL risk.

### OVL Token (ERC20)

1. Allows holders to participate in long/short trading of data streams

2. Gives holders governance stake in proposed data feeds and tuning of their risk parameters

3. Gives holders governance control over treasury: revenue from fees on each trade.

### OVL Position (ERC1155)

- Represents a trader's position, received upon locking up OVL in a trade on a data stream

- Unique identifiers are attrs of the position: Lock price, data feed name, long/short side, leverage

- Tradeable/transferrable on secondary markets given ERC1155 standard

### Spec

- **OVLToken (ERC20 Token):** Base token with public `mint()`, `burn()` functions through `AccessControl` privileges

- **OVLPosition (ERC1155 Token):** Positions as ERC1155 tokens allows for transfers on secondary markets

- **OVLFeed:** Proxy for the underlying data stream for prices

- Feed and trading position contracts act as pairs. Governance adds these together.

- Position contracts have admin access to OVL token contract for mint/burn functions

- Position contracts fetch prices from associated feed contract whenever updates to the position occur

- Keepers (i.e. any external actor) are incentivized to liquidate underwater positions through a reward of a portion (less fees) of the total OVL locked in the underwater position


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

### Monetary Policy

Overlay's monetary policy relies on revenues from trading fees charged when a user of the protocol builds or unwinds a position on a data stream. A portion of these fees are burnt upon trade execution to help manage currency supply. The rest are sent to a community governed treasury. Overlay’s community governed treasury passes through these fees to incentivize spot market liquidity providers (LPs), governance participants, and insurance fund providers as compensation for each of their services.

A high-level overview for each of the roles:

- **Spot Market LPs:** enable traders to swap OVL for ETH to enter/exit the Overlay system. LPs stake their Uniswap OVLETH LP tokens to earn yield in OVL.

- **Governance Participants:** determine the risk/reward parameters of and markets offered by the protocol to ensure the Overlay system remains useful over time. Governance participants stake OVL to earn yield in OVL.

- **Insurance Fund Providers:** backstop the protocol by locking up collateral for a governance-determined set amount of time, with an auction-and-burn mechanism in the event of any unanticipated excessive increase in the currency supply. Insurance fund providers can stake ETH, DAI, YFI, etc. in the treasury contract to earn yield in OVL, with downside risk of collateral loss.


### Currency Supply Stability Mechanisms

Overlay itself will be an automated market maker taking either side of any trade on the platform. Thus, it needs to keep a balanced set of outstanding positions to make sure trading on the exchange ultimately results in a zero sum game for those backstopping the system (and keeps currency supply stable). The mechanisms to do this:

- Overlay charges a fee on each trade on the exchange. 50% (tunable by governance) of those fees are burnt over time effectively causing a downward drift in the currency supply to mitigate any potential large gains from profitable traders all in the same position on a market.

- Overlay will implement a funding rate on each sampling of the underlying oracle feed. The funding rate keeps the floating price offered on the Overlay exchange on each market close to the oracle reported value. This mechanism effectively encourages arbitrageurs to take the other side of the trade and balance the Overlay outstanding positions on a market.

- We are currently simulating dynamic fees with agent based sims to see if they better encourage a balanced set of outstanding positions or if the funding rate is all we need. Sims will examine fees dependent on the difference in currency supply from initial supply and imbalance in open interest. You can follow along here if you like: [overlay-monetary](https://github.com/overlay-market/overlay-monetary)

### Revenue Model

Fees in OVL: 0.15% per trade, adjustable by governance on feed-by-feed basis

- 50% is burned
- 50% is sold for ETH via Uniswap through treasury

To incentivize OVLETH liquidity providers and governance contributors in perpetuity, take the 50% of the ETH to treasury and divide evenly between

- 33.33% to OVLETH LPs staking
- 33.33% to governance OVL stakers that vote
- 33.33% to ERC20 stakers in insurance fund

The weighting factors for each actor and fee rates can be adjusted by governance. Eventually lend out the locked OVL from positions for capital efficiency and additional revenue.

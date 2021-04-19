# Overlay Protocol

[whitepaper](https://firebasestorage.googleapis.com/v0/b/overlay-app-91fc7.appspot.com/o/OverlayWPv3.pdf?alt=media)

[spec](./specs/notes.md)

## WARNING

The **OVLFPosition** contract is incomplete in its current form. Implementation of the updates to the monetary policy and market position contracts to ensure the long-term stability and robustness of the system are in development.


## Contracts

For each feed type, we'll have a factory contract that governance uses to deploy all new oracle data streams to offer as markets, that are associated with that feed type.

Any new feed type we wish to support (e.g. Mirin, Chainlink, UniswapV3), will have the same setup. A factory contract to deploy the position contract for each new stream to offer as a market and stores all the market contracts offered as a registry **AND** the actual position contract for that market for traders to build/unwind with.


### Rinkeby

- **OVLToken:** 0x1c8D468bFdc4D7c153e34811de191AD08A33a278

- **OVLFPosition (BTCUSD Chainlink):** 0xec0d838f6A6ad46EF29D56EFeE39C7ce4CfA8B95

- **OVLChainlinkFeed (BTCUSD Chainlink):** 0x3aaAdBE9A830c54245F74E6E578ecA81482ec970

- **OVLFPosition (ETHUSD Chainlink):** 0xAc0BbA891576640d12019cD6449c3DFbF74683eA

- **OVLChainlinkFeed (ETHUSD Chainlink):** 0x131D62b8D89712F0927d080f2afdbed289c477dB

- **OVLFPosition (DAIUSD Chainlink):** 0xf73AEa5eBBcaED32e505044981C16A625043c376

- **OVLChainlinkFeed (DAIUSD Chainlink):** 0xF94284d95946229F16d3CB1a61ad47Ae02757cfe

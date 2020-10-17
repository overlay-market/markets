// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.6.7;

import "@openzeppelinV3/contracts/GSN/Context.sol";
import "@openzeppelinV3/contracts/math/SafeMath.sol";
import "@openzeppelinV3/contracts/math/SignedSafeMath.sol";

import "../../interfaces/chainlink/AggregatorV3Interface.sol";
import "../../interfaces/overlay/IOVLFeed.sol";
import "../../interfaces/overlay/IOVLPosition.sol";

contract OVLChainlinkFeed is Context, IOVLFeed {
  using SafeMath for uint256;
  using SignedSafeMath for int256;

  AggregatorV3Interface internal _chainlink;
  address public dataSource;
  uint256 public rounds; // # of rounds to avg TWAP over (~ 8h)

  constructor(address _data, uint256 _rounds) public {
    _chainlink = AggregatorV3Interface(_data);
    dataSource = _data;
    rounds = _rounds;
  }

  function getData() public view virtual override returns (int256, uint256) {
    // NOTE: 1h data for BTCUSD, 20m data for ETHUSD, 1h data for Fast gas
    (uint80 roundId, int256 price, , uint256 timestamp, ) = _chainlink.latestRoundData();
    require(timestamp > 0, "OVLChainlinkFeed: round not complete");

    // Get the TWAP over rounds
    uint256 period = 0;
    int256 cumPrice = 0;
    for (uint256 i=0; i < rounds; i++) {
      if (roundId == 0) {
        break;
      }
      roundId--;
      (, int256 prevRoundPrice, , uint256 prevRoundTimestamp, ) = _chainlink.getRoundData(roundId);

      uint256 delt = timestamp.sub(prevRoundTimestamp);
      cumPrice = cumPrice.add(price.mul(int256(delt)));
      period = period.add(delt);

      timestamp = prevRoundTimestamp;
      price = prevRoundPrice;
    }

    if (period != 0) {
      price = cumPrice.div(int256(period));
    }
    return (price, period);
  }
}

// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/SignedSafeMath.sol";

import "../interfaces/IOVLFeed.sol";
import "../interfaces/IOVLPosition.sol";


interface AggregatorV3Interface {
  function getRoundData(uint80 _roundId)
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );

  function latestRoundData()
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );
}

contract OVLChainlinkFeed is IOVLFeed {
  using SafeMath for uint256;
  using SignedSafeMath for int256;

  AggregatorV3Interface internal _chainlink;
  address public dataSource;
  uint256 public rounds; // # of rounds to avg TWAP over (~ 8h)

  constructor(address _data, uint256 _rounds) {
    _chainlink = AggregatorV3Interface(_data);
    dataSource = _data;
    rounds = _rounds;
  }

  function _fetch() private view returns (int256, uint256) {
    (uint80 roundId, int256 price, , uint256 timestamp, ) = _chainlink.latestRoundData();
    require(timestamp > 0, "OVLChainlinkFeed: round not complete");

    // Get the TWAP over rounds
    uint256 period = 0;
    int256 priceCumulative = 0;
    for (uint256 i=0; i < rounds; i++) {
      if (roundId == 0) {
        break;
      }
      roundId--;
      (, int256 prevRoundPrice, , uint256 prevRoundTimestamp, ) = _chainlink.getRoundData(roundId);

      uint256 delt = timestamp.sub(prevRoundTimestamp);
      priceCumulative = priceCumulative.add(price.mul(int256(delt)));
      period = period.add(delt);

      timestamp = prevRoundTimestamp;
      price = prevRoundPrice;
    }

    if (period != 0) {
      price = priceCumulative.div(int256(period));
    }
    return (price, period);
  }

  function data() external view returns (int256, uint256) {
    return _fetch();
  }

  function fetchData() public virtual override returns (int256, uint256) {
    return _fetch();
  }
}

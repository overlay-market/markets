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

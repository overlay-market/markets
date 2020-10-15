// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.6.7;

import "@openzeppelinV3/contracts/GSN/Context.sol";
import "@openzeppelinV3/contracts/math/SignedSafeMath.sol";

import "../../interfaces/chainlink/AggregatorV3Interface.sol";
import "../../interfaces/overlay/IOVLFeed.sol";
import "../../interfaces/overlay/IOVLPosition.sol";

contract OVLChainlinkFeed is Context, IOVLFeed {
  AggregatorV3Interface internal _chainlink;
  address public dataSource;

  constructor(address _data) public {
    _chainlink = AggregatorV3Interface(_data);
    dataSource = _data;
  }

  function getData() public view virtual override returns (int256) {
    // NOTE: 1h data for BTCUSD, 20m data for ETHUSD, 1h data for Fast gas
    (, int256 price, , uint256 timestamp, ) = _chainlink.latestRoundData();
    require(timestamp > 0, "OVLChainlinkFeed: round not complete");
    return price;
  }
}

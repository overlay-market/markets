// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.6.0;

import "@openzeppelinV3/contracts/math/SignedSafeMath.sol";

library SignedMath {

  using SignedSafeMath for int256;

  function abs(int256 a) internal pure returns (int256) {
    return a >= 0 ? a : a.mul(-1);
  }

}

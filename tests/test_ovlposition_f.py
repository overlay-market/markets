import pytest

from brownie import OVLToken, OVLFPosition, OVLTestFeed, accounts


@pytest.fixture
def deployment():
    gov = accounts[0]
    token = OVLToken.deploy("Overlay Test Token", "OVL", { 'from': gov })
    token.grantRole(token.MINTER_ROLE(), gov.address, { 'from': gov })
    token.mint(1000*1e18, {'from': gov})
    token.transfer(accounts[1], 1000*1e18, {'from': gov})

    feed = OVLTestFeed.deploy({'from': gov})
    feed.setData(375*1e8)

    pos = OVLFPosition.deploy("uri", token.address, feed.address, {
        'from': gov
    })
    token.grantRole(token.MINTER_ROLE(), pos.address, { 'from': gov })
    token.increaseAllowance(pos.address, 1000*1e18, {'from': accounts[1]})
    return token, feed, pos

def test_deployment(deployment):
    token, feed, pos = deployment
    gov = accounts[0]
    assert pos.governance() == gov.address
    assert pos.treasury() == gov.address
    assert pos.feed() == feed.address
    assert pos.token() == token.address

def test_build(deployment):
    token, feed, pos = deployment
    gov = accounts[0]
    acc = accounts[1]
    pos.build(100*1e18, True, 1e18, {'from': acc})
    id = pos.getId(True, 1e18, 375*1e8)

    # Check pos attrs
    assert id == pos.open()[-1]
    assert pos.isLong(id) == True
    assert pos.leverageOf(id) == 1e18
    assert pos.lockPriceOf(id) == 375*1e8

    # Check balances and fees
    assert token.balanceOf(acc.address) == 900*1e18
    assert token.balanceOf(pos.address) == 100*1e18 * (1-0.0015) # extracted trade fees
    assert pos.balanceOf(acc.address, id) == pos.amountLockedIn(id) == 100*1e18 * (1-0.0015)
    assert token.balanceOf(pos.treasury()) == (100*1e18 * 0.0015/2.0) # treasury gets half the fees, other half gets burned
    assert token.totalSupply() == (1000*1e18 - 100*1e18 * 0.0015/2.0)

def test_unwind(deployment):
    # TODO: build the positions first as above but without asserts ...
    pass

def test_liquidate(deployment):
    pass

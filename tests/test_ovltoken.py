import pytest

from brownie import OVLToken, accounts

BASE = 1e18

@pytest.fixture
def token():
    token = OVLToken.deploy("Overlay", "OVL", {
        'from': accounts[0],
    })
    token.grantRole(token.MINTER_ROLE(), accounts[1].address, {
        'from': accounts[0]
    })
    return token

def test_mint(token):
    token.mint(100*BASE, {'from': accounts[1]})
    assert token.totalSupply() == 100*BASE
    assert token.balanceOf(accounts[1]) == 100*BASE

def test_burn(token):
    token.mint(100*BASE, {'from': accounts[1]})
    token.transfer(accounts[2], 10*BASE, {'from': accounts[1]})
    assert token.balanceOf(accounts[1]) == 90*BASE
    token.burn(60*BASE, {'from': accounts[1]})
    assert token.totalSupply() == 40*BASE
    assert token.balanceOf(accounts[1]) == 30*BASE

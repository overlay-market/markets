import pytest
from brownie import MasterChefToken, OVLToken, ERC20Mock, web3


@pytest.fixture
def deployer(accounts):
    yield accounts[0]


@pytest.fixture
def spot(accounts):
    yield accounts[1]


@pytest.fixture
def staker(accounts):
    yield accounts[2]


@pytest.fixture
def rando(accounts):
    yield accounts[3]


@pytest.fixture
def create_token():
    def create_token(*args):
        dep = args[0]
        return dep.deploy(*args[1:])

    yield create_token


@pytest.fixture
def lp_tokens(staker, spot, create_token):
    LP_PARAMS = [("LP Token 1", "LP1"), ("LP Token 2", "LP2"), ("LP Token 3", "LP3")]
    lps = [create_token(*[spot, ERC20Mock, *p]) for p in LP_PARAMS]
    for i, lp in enumerate(lps):
        lp.mint(staker, i*10 * (10**(lp.decimals())), {'from': spot})

    yield lps


@pytest.fixture
def reward_token(deployer, create_token):
    yield create_token(*[deployer, OVLToken])


@pytest.fixture
def rando_token(rando, create_token):
    yield create_token(*[rando, ERC20Mock, "Rando Token", "RT"])


@pytest.fixture
def chef(deployer, reward_token, lp_tokens, create_token):
    args = (
        reward_token,
        deployer.address,
        15 * 10**(reward_token.decimals()),
        web3.eth.blockNumber,
        web3.eth.blockNumber+1000,
    )
    chef = create_token(*[deployer, MasterChefToken, *args])
    reward_token.grantRole(
        reward_token.MINTER_ROLE(),
        chef.address,
        {'from': deployer}
    )
    for i, lp_token in enumerate(lp_tokens):
        allocation = 2.0 if i == len(lp_tokens) - 1 else 1.0
        chef.add(allocation, lp_token, False, {'from': deployer})

    yield chef


def test_chef_as_token(chef, staker, deployer):
    assert chef.uri(1) == "https://farm.overlay.market/api/pools/{id}.json"
    assert chef.balanceOf(staker, 0) == 0.0

    n_pools = chef.poolLength()
    ids = [i for i in range(n_pools)]
    accounts = [staker for i in range(n_pools)]
    zero_balances = [0.0 for i in range(n_pools)]
    assert chef.balanceOfBatch(accounts, ids) == zero_balances
    assert chef.devaddr() == deployer.address
    assert chef.owner() == deployer.address


def test_deposit(chef, staker, lp_tokens):
    # TODO:
    #  1. Make sure mints appropriate amount of erc 1155 (check balance of)
    pass

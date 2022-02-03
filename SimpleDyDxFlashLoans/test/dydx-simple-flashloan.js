const { legos } = require("@studydefi/money-legos");

require('chai')
  .use(require('chai-as-promised'))
  .should()
  .assert()

const IERC20 = artifacts.require('IERC20');
const SimpleDyDxFlashloan = artifacts.require('SimpleDyDxFlashloan');

contract('SimpleDyDxFlashloan', ([acc]) => {
  let contract, dai, uniswap, daiSwap, daiSwapAddress, flashloan_user, user;
  const DAI = '0x6B175474E89094C44Da98b954EedeAC495271d0F';


  beforeEach(async () => {
    //contracts declaration for swapping ETH=>DAI
    dai = await IERC20.at(DAI);
    // dai = new web3.eth.Contract(legos.erc20.dai.abi, legos.erc20.dai.address)
    uniswap = new web3.eth.Contract(legos.uniswap.factory.abi, legos.uniswap.factory.address)
    daiSwapAddress = await uniswap.methods.getExchange(legos.erc20.dai.address).call()
    daiSwap = new web3.eth.Contract(legos.uniswap.exchange.abi, daiSwapAddress)
    flashloan_user = accounts[0]

    //swap 1 ETH=>DAI
    await daiSwap.methods.ethToTokenSwapInput(1, 2525644800).send({from: acc, value: web3.utils.toWei('1', 'Ether')})
    
    contract = await SimpleDyDxFlashloan.new()

    console.log(`contract address is: ${contract.address}`)

    //send 1 DAI to contract (for flash loan fee)
    await dai.transfer(contract.address, web3.utils.toWei('1', 'ether'), {from: acc})
  })

  describe('Performing Flash Loan...', () => {
    it('Borrowing 1M DAI and throws revert info msg.', async () => {
      await contract.initiateFlashLoan(
        token.address,
        web3.utils.toWei('1000000', 'Ether')
      ).should.be.rejectedWith("!You got desired funds, now code what to do next")
    })
  })
})

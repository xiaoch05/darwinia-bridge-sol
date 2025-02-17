const { BigNumber } = require("ethers");
const {
  mine, printTxPromiseGas,
  createBeefyValidatorFixture,
  createRandomPositions,
  createAllValidatorProofs,
  createCompleteValidatorProofs,
  createSingleValidatorProof,
} = require("./shared/helpers");
const beefyFixture = require('./shared/beefy-data.json');

require("chai")
  .use(require("chai-as-promised"))
  .should();

const { expect } = require("chai");

describe("Light Client Gas Usage", function () {

  const testCases = [
    {
      totalNumberOfValidators: 10,
      totalNumberOfSignatures: 7,
    },
    {
      totalNumberOfValidators: 15,
      totalNumberOfSignatures: 15,
    },
    {
      totalNumberOfValidators: 25,
      totalNumberOfSignatures: 25,
    },
    {
      totalNumberOfValidators: 30,
      totalNumberOfSignatures: 30,
    },
    {
      totalNumberOfValidators: 35,
      totalNumberOfSignatures: 35,
    },
    {
      totalNumberOfValidators: 36,
      totalNumberOfSignatures: 36,
    },
    {
      totalNumberOfValidators: 40,
      totalNumberOfSignatures: 40,
    },
    {
      totalNumberOfValidators: 50,
      totalNumberOfSignatures: 50,
    },
    {
      totalNumberOfValidators: 100,
      totalNumberOfSignatures: 100,
    },
    {
      totalNumberOfValidators: 128,
      totalNumberOfSignatures: 128,
    },
    {
      totalNumberOfValidators: 257,
      totalNumberOfSignatures: 257,
    },
    {
      totalNumberOfValidators: 1000,
      totalNumberOfSignatures: 1000,
    },
    {
      totalNumberOfValidators: 1000,
      totalNumberOfSignatures: 667,
    },
    {
      totalNumberOfValidators: 1025,
      totalNumberOfSignatures: 684,
    },
    {
      totalNumberOfValidators: 2048,
      totalNumberOfSignatures: 1366,
    },
  ]

  for (const testCase of testCases) {
    it(`runs full flow with ${testCase.totalNumberOfValidators} validators and ${testCase.totalNumberOfSignatures} signers with the complete transaction succeeding`,
      async function () {
        this.timeout(1000 * 200);
        await runFlow(testCase.totalNumberOfValidators, testCase.totalNumberOfSignatures)
      });
  }

  const runFlow = async function (totalNumberOfValidators, totalNumberOfSignatures) {
    console.log(`Running flow with ${totalNumberOfValidators} validators and ${totalNumberOfSignatures} signatures with the complete transaction succeeding: `)

    const fixture = await createBeefyValidatorFixture(
      totalNumberOfValidators
    )
    const LightClientBridge = await ethers.getContractFactory("DarwiniaLightClient");
    const crab = beefyFixture.commitment.payload.network
    const vault = "0x0000000000000000000000000000000000000000"
    beefyLightClient = await LightClientBridge.deploy(
      crab,
      vault,
      0,
      totalNumberOfValidators,
      fixture.root,
    );

    const initialBitfieldPositions = await createRandomPositions(totalNumberOfSignatures, totalNumberOfValidators)

    const firstPosition = initialBitfieldPositions[0]

    const initialBitfield = await beefyLightClient.createInitialBitfield(
      initialBitfieldPositions, totalNumberOfValidators
    );

    const commitmentHash = await beefyLightClient.hash(beefyFixture.commitment);

    const allValidatorProofs = await createAllValidatorProofs(commitmentHash, fixture);

    const firstProof = await createSingleValidatorProof(firstPosition, fixture)

    let overrides = {
        value: ethers.utils.parseEther("4")
    };
    const newSigTxPromise = beefyLightClient.newSignatureCommitment(
      commitmentHash,
      initialBitfield,
      allValidatorProofs[firstPosition].signature,
      firstPosition,
      allValidatorProofs[firstPosition].address,
      firstProof,
      overrides
    )
    printTxPromiseGas("1-step", await newSigTxPromise)
    await newSigTxPromise.should.be.fulfilled

    const lastId = (await beefyLightClient.currentId()).sub(BigNumber.from(1));

    await mine(20);

    const completeValidatorProofs = await createCompleteValidatorProofs(lastId, beefyLightClient, allValidatorProofs, fixture);

    const completeSigTxPromise = beefyLightClient.completeSignatureCommitment(
      lastId,
      beefyFixture.commitment,
      completeValidatorProofs
    )
    await printTxPromiseGas("2-step", await completeSigTxPromise)
    await completeSigTxPromise.should.be.fulfilled
    latestMMRRoot = await beefyLightClient.latestMMRRoot()
    expect(latestMMRRoot).to.eq(beefyFixture.commitment.payload.mmr)
  }

});

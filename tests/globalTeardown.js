/**
 * Global Teardown
 * Runs once after all tests
 */

module.exports = async () => {
  console.log('\n✅ Test suite completed!\n');

  // Clean up
  await new Promise(resolve => setTimeout(resolve, 1000));
};

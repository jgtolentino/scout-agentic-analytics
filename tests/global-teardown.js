/**
 * Global Teardown for Scout Design System Tests
 * 
 * Cleans up and generates reports after test execution
 */

const fs = require('fs');
const path = require('path');

async function globalTeardown() {
  console.log('🧹 Running global teardown...');

  // Generate test summary report
  const testResultsPath = 'test-results/results.json';
  
  if (fs.existsSync(testResultsPath)) {
    try {
      const results = JSON.parse(fs.readFileSync(testResultsPath, 'utf8'));
      
      const summary = {
        timestamp: new Date().toISOString(),
        totalTests: results.stats?.total || 0,
        passed: results.stats?.passed || 0,
        failed: results.stats?.failed || 0,
        duration: results.stats?.duration || 0,
        visualDiffsDetected: 0,
        tokenValidationResults: []
      };

      // Count visual differences from test results
      if (results.suites) {
        const countVisualDiffs = (suites) => {
          let count = 0;
          suites.forEach(suite => {
            if (suite.tests) {
              suite.tests.forEach(test => {
                if (test.title.includes('screenshot') || test.title.includes('visual')) {
                  if (test.outcome !== 'expected') {
                    count++;
                  }
                }
              });
            }
            if (suite.suites) {
              count += countVisualDiffs(suite.suites);
            }
          });
          return count;
        };
        
        summary.visualDiffsDetected = countVisualDiffs(results.suites);
      }

      // Write summary report
      fs.writeFileSync(
        'test-results/visual-test-summary.json', 
        JSON.stringify(summary, null, 2)
      );

      // Generate markdown report
      const markdownReport = `# Scout Design System Test Report

Generated: ${summary.timestamp}

## Test Summary
- **Total Tests**: ${summary.totalTests}
- **Passed**: ${summary.passed}
- **Failed**: ${summary.failed}
- **Duration**: ${Math.round(summary.duration / 1000)}s
- **Visual Differences Detected**: ${summary.visualDiffsDetected}

## Token Validation
${summary.visualDiffsDetected === 0 ? '✅ All visual tests passed' : '⚠️ Visual differences detected - review screenshots'}

## Files Generated
- Screenshots: \`test-results/screenshots/\`
- Visual diffs: \`test-results/visual-diffs/\`
- Test report: \`test-results/report.html\`

## Next Steps
${summary.failed > 0 ? 
  '1. Review failed tests in the HTML report\n2. Check visual differences in screenshots\n3. Update baselines if changes are intentional' :
  'All tests passed! Design tokens are consistent across the application.'
}
`;

      fs.writeFileSync('test-results/REPORT.md', markdownReport);

      console.log('📊 Test Results Summary:');
      console.log(`   Tests: ${summary.passed}/${summary.totalTests} passed`);
      console.log(`   Visual diffs: ${summary.visualDiffsDetected}`);
      console.log(`   Duration: ${Math.round(summary.duration / 1000)}s`);
      
      if (summary.visualDiffsDetected > 0) {
        console.log('⚠️  Visual differences detected - check test-results/');
      } else {
        console.log('✅ All visual tests passed');
      }

    } catch (error) {
      console.error('❌ Failed to process test results:', error.message);
    }
  }

  // Clean up temporary files
  const tempFiles = [
    'test-results/.tmp.css',
    'test-results/.tmp.less.css'
  ];

  tempFiles.forEach(file => {
    if (fs.existsSync(file)) {
      fs.unlinkSync(file);
    }
  });

  console.log('✅ Global teardown completed');
}

module.exports = globalTeardown;
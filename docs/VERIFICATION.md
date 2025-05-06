# Example Verification System

## Overview
To maintain high-quality, up-to-date examples in our execution environment configurations, we've implemented a verification system. This system allows community members to verify and validate example configurations, ensuring they work as expected with current versions of the tools and platforms.

## Verification Status Format
Each example file includes a verification header with the following metadata:

```yaml
# Last Verified:
#   Date: YYYY-MM-DD | Not verified yet
#   Version: X.Y.Z
#   Verified By: @github_username | None
#   OpenShift Version: X.Y (if applicable)
#   Status: ✅ Verified | ⚠️ Needs Verification | ⚠️ Partial | ❌ Failed
#   Notes: Brief notes about testing conditions or limitations
```

### Initial Status
New examples start with:
- Date: "Not verified yet"
- Version: "0.1.0"
- Verified By: "None"
- Status: "⚠️ Needs Verification"
- Notes: Indicating it's awaiting initial community verification

This helps clearly identify which examples need community testing and verification.

## How to Verify an Example

1. **Test the Example**
   - Clone the repository
   - Build the execution environment using the example configuration
   - Test all major functionality described in the example
   - Document any issues or limitations found

2. **Update the Verification Status**
   - Update the verification header in the example file
   - Use your GitHub username in the "Verified By" field
   - Add relevant notes about your testing
   - Set appropriate status emoji:
     - ✅ Verified: Everything works as expected
     - ⚠️ Partial: Works with some limitations
     - ❌ Failed: Major issues found

3. **Submit Your Verification**
   - Create a pull request with your changes
   - Include test results or screenshots in the PR description
   - Reference any issues or discussions related to your verification

## Verification Guidelines

- Verifications should be done at least every 6 months
- Priority should be given to examples that haven't been verified recently
- If you find issues, create an issue in addition to updating the status
- Include specific version numbers of key components tested
- Document any workarounds or special configurations needed

## Review Process

1. Maintainers will review verification PRs for:
   - Completeness of testing
   - Accuracy of documentation
   - Validity of any reported issues

2. After review:
   - Approved verifications will be merged
   - Failed verifications will trigger issue creation
   - Partial verifications may need additional testing

## Contributing New Examples

When contributing new examples:
1. Include the verification header with initial "Needs Verification" status
2. Set version to "0.1.0" until first verification
3. Document any dependencies or prerequisites
4. Follow the existing example format and style
5. Note any specific testing requirements or considerations

## Automated Verification

We're working on implementing automated verification where possible. This may include:
- GitHub Actions for basic syntax validation
- Integration tests for core functionality
- Dependency version checking
- Regular scheduled builds

## Questions or Issues?

If you have questions about the verification process or find issues with an example:
1. Check existing issues and discussions
2. Create a new issue with detailed information
3. Join our community discussions 
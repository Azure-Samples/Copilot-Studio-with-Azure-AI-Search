# Decision Log 003: Agent SDK Authentication Strategy for Testing

**Date:** 2025-07-30  
**Status:** Approved

## Context

Our end-to-end testing strategy requires automated testing of Copilot Studio agents to validate the end-to-end flow of responses from the Azure resources to the Copilot Studio agent. We evaluated multiple approaches for implementing these tests, considering authentication requirements, platform support, and operational complexity.

The key testing approaches considered were:
- **Agent SDK with Service Principal Authentication**: Programmatic access using client credentials
- **Agent SDK with User-Based Authentication**: Username/password authentication with real user accounts
- **Copilot Studio Built-in Evaluation Tools**: Native evaluation capabilities within the Copilot Studio platform

Our solution requires reliable, automated testing that can be integrated into CI/CD pipelines while providing comprehensive validation of the AI search integration functionality.

## Decision

We will use **Agent SDK with User-Based Authentication** as our primary testing approach for Copilot Studio agent validation.

## Rationale

1. **Broadest Platform Support**: Agent SDK provides comprehensive support across Microsoft's AI technologies, including Copilot Studio, Foundry, and other conversational AI tools. This gives us maximum flexibility and ensures our testing approach aligns with Microsoft's recommended practices.

2. **Current Authentication Limitations**: Agent SDK does not currently support service principal authentication for Copilot Studio scenarios. While this limits our automation options, user-based authentication is the only viable approach for programmatic testing at this time.

3. **Proven Functional Capability**: We have successfully validated that user-based authentication works reliably for our testing scenarios, providing the functionality needed to execute comprehensive end-to-end tests.

4. **Native SDK Benefits**: Using the official Agent SDK ensures we stay aligned with Microsoft's evolving API surface and receive support for new features as they become available.

## Trade-offs and Considerations

### Accepted Trade-offs

- **MFA Requirement**: User-based authentication requires test accounts with Multi-Factor Authentication (MFA) disabled or configured with app passwords, which introduces security considerations that must be managed through proper test account governance.

- **Credential Management**: User credentials require more careful handling compared to service principals, necessitating additional security measures in our testing infrastructure.

- **Account Lifecycle**: Test user accounts require ongoing management and may be subject to organizational password policies and account lifecycle requirements.

### Alternative Approaches Considered

1. **Copilot Studio Built-in Evaluation Tools**
   - **Status**: Currently in private preview
   - **Benefits**: Lower effort setup, designed specifically for low-code users, integrated with Copilot Studio platform
   - **Limitations**: Not publicly available, limited programmatic control, unclear CI/CD integration capabilities
   - **Future Consideration**: This will be reevaluated when these tools reach general availability

2. **Service Principal Authentication**
   - **Status**: Not supported by Agent SDK for Copilot Studio
   - **Benefits**: Better security model, easier credential management, standard for enterprise automation
   - **Limitations**: Currently not available for our use case
   - **Future Consideration**: Will be adopted immediately when Agent SDK adds this capability

## Implementation Requirements

1. **Test Account Management**: Establish dedicated test accounts with appropriate security configurations
2. **Credential Security**: Implement secure credential storage and handling practices in CI/CD pipelines
3. **Error Handling**: Robust authentication error handling and retry logic for transient failures
4. **Monitoring**: Track authentication success/failure rates and account health

## Future Considerations

- **Service Principal Support**: Monitor Agent SDK releases for service principal authentication support and migrate when available
- **Copilot Studio Evaluation Tools**: Evaluate built-in tools when they reach general availability and assess integration with our testing strategy
- **Hybrid Approach**: Consider combining multiple testing approaches as capabilities mature to provide comprehensive coverage

## Related Decisions

- This decision supports the overall testing strategy established in our CI/CD pipeline design
- Security considerations align with our credential management policies outlined in infrastructure security practices


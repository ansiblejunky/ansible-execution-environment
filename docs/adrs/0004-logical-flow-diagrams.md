# [ADR-0004] Logical Flow Diagrams

## Status

Accepted

## Context

Complex automation processes in Ansible Execution Environments need clear visualization to:
- Help team members understand process flows
- Document system interactions
- Aid in troubleshooting
- Support onboarding and knowledge transfer

## Decision

We will implement standardized logical flow diagrams using Mermaid.js for the following processes:

1. Build Process Flow:
```mermaid
graph TD
    A[Start Build] --> B[Load Environment Variables]
    B --> C[Validate Dependencies]
    C --> D[Build EE Image]
    D --> E[Run Tests]
    E --> F[Security Scan]
    F --> G{Pass?}
    G -->|Yes| H[Push Image]
    G -->|No| I[Report Failure]
```

2. Test Process Flow:
```mermaid
graph TD
    A[Start Test] --> B[Container Test]
    B --> C[AAP Integration]
    C --> D[Syntax Check]
    D --> E[Security Scan]
    E --> F{All Pass?}
    F -->|Yes| G[Report Success]
    F -->|No| H[Report Failures]
```

3. Deployment Flow:
```mermaid
graph TD
    A[Start Deploy] --> B[Image Pull]
    B --> C[Validate Image]
    C --> D[Update AAP]
    D --> E[Health Check]
    E --> F{Healthy?}
    F -->|Yes| G[Update Complete]
    F -->|No| H[Rollback]
```

4. Authentication Flow:
```mermaid
sequenceDiagram
    participant Script as Bootstrap Script
    participant Token as Token Validation
    participant SSO as Red Hat SSO
    participant Hub as Automation Hub
    participant DNS as DNS Resolution
    participant API as API Endpoints

    Script->>Token: Validate Token Format
    Note over Token: Check JWT Structure<br/>Validate Expiry/Claims
    
    alt Token Valid
        Script->>SSO: Request Access Token
        SSO-->>Script: Access Token
        
        Script->>DNS: Resolve API Endpoints
        DNS-->>Script: Resolution Status
        
        alt DNS Success
            Script->>Hub: Test API Access
            Hub-->>Script: API Response
            
            Script->>API: Test Collection Access
            API-->>Script: Collection Data
            
            alt Access Success
                Script->>API: Download Collection
                API-->>Script: Collection Content
            else Access Failure
                API-->>Script: Error Response
                Note over Script: Handle API Error
            end
        else DNS Failure
            DNS-->>Script: Resolution Error
            Note over Script: Handle DNS Error
        end
    else Token Invalid
        Token-->>Script: Validation Error
        Note over Script: Handle Token Error
    end
```

5. Error Handling Flow:
```mermaid
graph TD
    A[Start Operation] --> B{Validate Token}
    B -->|Invalid| C[Log Token Error]
    C --> D[Exit with Status]
    
    B -->|Valid| E{Check SSO Access}
    E -->|Failed| F[Log SSO Error]
    F --> D
    
    E -->|Success| G{Test API Access}
    G -->|Failed| H[Log API Error]
    H --> I[Check Error Type]
    I -->|Auth| J[Token Refresh]
    I -->|Permission| K[Access Check]
    I -->|Network| L[Connection Test]
    
    G -->|Success| M{Download Collection}
    M -->|Failed| N[Log Download Error]
    M -->|Success| O[Verify Content]
    
    J --> D
    K --> D
    L --> D
    N --> D
    O --> P[Operation Complete]
```

6. Token Validation Flow:
```mermaid
graph TD
    A[Start Validation] --> B{Check JWT Format}
    B -->|Invalid| C[Log Format Error]
    C --> D[Exit with Status]
    
    B -->|Valid| E{Validate Claims}
    E -->|Invalid| F[Log Claims Error]
    F --> D
    
    E -->|Valid| G{Check Expiry}
    G -->|Expired| H[Log Expiry Error]
    H --> I[Attempt Refresh]
    I -->|Failed| J[Log Refresh Error]
    I -->|Success| K[Update Token]
    
    G -->|Valid| L[Token OK]
    K --> L
    
    J --> D
    L --> M[Continue]
```

Standards:
1. Use Mermaid.js for all diagrams
2. Follow left-to-right or top-down flow
3. Use consistent shapes:
   - Rectangles for processes
   - Diamonds for decisions
   - Rounded rectangles for start/end
4. Include diagram source in markdown files
5. Keep diagrams focused and simple

## Consequences

### Positive
- Clear visual documentation
- Self-documenting processes
- Easy to maintain with source control
- Rendered directly in GitHub/GitLab
- Consistent visualization across project

### Negative
- Need to learn Mermaid.js syntax
- Additional documentation to maintain
- May need external tools for editing
- Limited styling options

## Alternatives Considered

1. **Draw.io/Diagrams.net**
   - More feature-rich
   - Binary files in repo
   - Harder to version control
   - Rejected for maintainability

2. **PlantUML**
   - Similar features
   - Requires external server/tools
   - Less GitHub integration
   - Rejected for complexity

3. **ASCII Art Diagrams**
   - Simple to create
   - Limited capabilities
   - Hard to maintain
   - Rejected for scalability

## References

- [Mermaid.js Documentation](https://mermaid.js.org/)
- [GitHub Mermaid Support](https://github.blog/2022-02-14-include-diagrams-markdown-files-mermaid/)
- [Diagram Best Practices](https://www.lucidchart.com/blog/how-to-make-a-flow-chart)

## Notes

- Consider automated diagram validation
- Keep diagrams up to date with code changes
- Use consistent naming conventions
- Include legends for complex diagrams 
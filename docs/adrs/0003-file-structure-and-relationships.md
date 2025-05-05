# [ADR-0003] File Structure and Relationships

## Status

Accepted

## Context

An Ansible Execution Environment project requires multiple configuration files, scripts, and documentation that need to work together cohesively. We need to establish a clear file structure that:
- Makes the project easy to navigate
- Clearly shows file relationships and dependencies
- Follows industry best practices
- Supports maintainability and scalability

## Decision

We will organize the project with the following file structure and relationships:

1. Root Level Configuration:
   ```
   ├── execution-environment.yml    # Primary EE configuration
   ├── ansible-navigator.yml       # Navigator settings
   ├── .yamllint.yml              # YAML linting rules
   ├── .env-example               # Template for environment variables
   └── Makefile                   # Build and management commands
   ```

2. Documentation Structure:
   ```
   ├── README.md                  # Project overview and quick start
   ├── bootstrap.md               # Initial setup instructions
   └── docs/
       ├── adrs/                 # Architecture Decision Records
       └── *.md                  # Additional documentation
   ```

3. Build and Test Files:
   ```
   ├── requirements.yml           # Ansible collection dependencies
   ├── requirements.txt          # Python package dependencies
   ├── bindep.txt               # System package dependencies
   └── files/
       ├── provision.sh         # Environment provisioning
       ├── container-test.sh    # Container testing
       └── test-aap-integration.sh  # AAP integration tests
   ```

4. Development Support:
   ```
   ├── .github/
   │   └── workflows/           # CI/CD pipeline definitions
   └── .kanbn/                  # Kanban board configuration
   ```

Key Relationships:
1. `execution-environment.yml` references:
   - `requirements.yml`
   - `requirements.txt`
   - `bindep.txt`

2. `Makefile` orchestrates:
   - Build process using `execution-environment.yml`
   - Testing using scripts in `files/`
   - Environment setup using `.env`

3. Documentation relationships:
   - `README.md` links to `bootstrap.md` and ADRs
   - ADRs cross-reference each other
   - All docs reference relevant configuration files

## Consequences

### Positive
- Clear separation of concerns
- Easy to find related files
- Consistent with industry standards
- Supports automated builds and testing
- Self-documenting structure

### Negative
- More directories to maintain
- Need to keep documentation in sync
- Multiple places to update for changes
- Learning curve for new team members

## Alternatives Considered

1. **Flat File Structure**
   - Simpler organization
   - Harder to maintain as project grows
   - Poor separation of concerns
   - Rejected for scalability reasons

2. **Monolithic Configuration**
   - Single configuration file
   - Harder to maintain
   - Less flexibility
   - Rejected for maintainability

3. **Feature-based Structure**
   - Group files by feature
   - More complex navigation
   - Non-standard for EE projects
   - Rejected for consistency with ecosystem

## References

- [Ansible Best Practices Directory Layout](https://docs.ansible.com/ansible/latest/tips_tricks/sample_setup.html)
- [Python Project Structure](https://docs.python-guide.org/writing/structure/)
- [Git Repository Structure](https://github.com/kriasoft/Folder-Structure-Conventions)

## Notes

- Consider using symlinks for frequently accessed files
- Maintain consistent naming conventions
- Keep documentation close to related code
- Use relative links in documentation 
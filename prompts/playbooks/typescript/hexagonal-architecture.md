# TypeScript Hexagonal Architecture

## Directory Structure

```
src/
├── main.ts
├── shared/
│   ├── utils/
│   ├── constants/
│   └── types/
├── application/
│   ├── ports/
│   │   ├── input/
│   │   └── output/
│   ├── use-cases/
│   └── services/
├── domain/
│   ├── entities/
│   ├── value-objects/
│   ├── aggregates/
│   └── events/
├── infrastructure/
│   ├── adapters/
│   │   ├── input/
│   │   │   ├── rest/
│   │   │   ├── graphql/
│   │   │   └── cli/
│   │   └── output/
│   │       ├── persistence/
│   │       ├── messaging/
│   │       └── external-apis/
│   ├── config/
│   └── database/
└── tests/
    ├── unit/
    ├── integration/
    └── e2e/
```

### Layer Descriptions

**main.ts**
- Entry point and application bootstrap
- Dependency injection setup
- Framework initialization (e.g., NestJS, Express)

**shared**
- Common utilities, constants, and type definitions
- Cross-cutting concerns (logging, validation, error handling)
- Shared value objects and domain primitives

**application**
- Application layer orchestrating business logic
- **ports/input**: Inbound interfaces (use case interfaces)
- **ports/output**: Outbound interfaces (repository, external service interfaces)
- **use-cases**: Application-specific business rules
- **services**: Application services coordinating domain logic

**domain**
- Core business logic (framework-independent)
- **entities**: Domain objects with identity
- **value-objects**: Immutable objects without identity
- **aggregates**: Consistency boundaries for entities
- **events**: Domain events for state changes

**infrastructure**
- External concerns and framework-specific code
- **adapters/input**: Primary adapters (controllers, CLI handlers, event listeners)
- **adapters/output**: Secondary adapters (database repositories, external API clients)
- **config**: Configuration management
- **database**: Database schemas, migrations, seeders

### Layer Dependencies

```
infrastructure → application → domain
     ↓              ↓
   (ports)    (ports/input + ports/output)
```

**Dependency Rule**: Dependencies point inward
- Infrastructure depends on Application and Domain
- Application depends on Domain
- Domain has NO external dependencies

## TypeScript Coding Style

### Type System
- **Strict Mode**: Enable all strict TypeScript options
  ```json
  {
    "strict": true,
    "strictNullChecks": true,
    "strictFunctionTypes": true,
    "noImplicitAny": true
  }
  ```
- **Type Safety**: Prefer types over interfaces for domain models
- **Generics**: Use for reusable components and repositories

### Naming Conventions
- **Classes**: PascalCase (`UserEntity`, `EmailValueObject`)
- **Interfaces/Types**: PascalCase with descriptive names (`CreateUserPort`, `UserRepository`)
- **Functions/Methods**: camelCase (`createUser`, `findByEmail`)
- **Constants**: UPPER_SNAKE_CASE (`MAX_RETRIES`, `DEFAULT_TIMEOUT`)
- **Private Members**: Prefix with `_` or use TypeScript `private`

### Code Organization
- **Barrel Exports**: Use `index.ts` for clean imports
- **Single Responsibility**: One class/function per file
- **Dependency Injection**: Use constructor injection
- **Immutability**: Prefer `readonly` and immutable patterns

### Port Naming Conventions
- **Input Ports** (Use Cases): `<Action><Entity>UseCase` or `<Action><Entity>Port`
  - Example: `CreateUserUseCase`, `FindUserByIdPort`
- **Output Ports** (Repositories): `<Entity>Repository`, `<Service>Port`
  - Example: `UserRepository`, `EmailServicePort`

## Test Strategy (TDD)

Follow t-wada style Test-Driven Development (TDD)

### Cycle
🔴 Red » 🟢 Green » 🔵 Refactor

### Process
1. Create TODO list
2. Write failing test
3. Minimal implementation (fake it till you make it)
4. Refactor

### Principles
- Small incremental steps
- Triangulation for generalization
- Test the behavior, not implementation
- Keep test list updated

### Triangulation Example

1. **Fake Implementation**: `return 'john@example.com'`
   ```typescript
   expect(email.getValue()).toBe('john@example.com')
   ```

2. **Generalization**: `return this.value`
   ```typescript
   expect(Email.create('alice@example.com').getValue()).toBe('alice@example.com')
   ```

3. **Edge Cases**
   ```typescript
   expect(() => Email.create('invalid-email')).toThrow()
   expect(() => Email.create('')).toThrow()
   ```

### Best Practices
- **1 Test :: 1 Behavior**: Each test validates one specific behavior
- **Red-Green Commit**: Commit after each Red→Green cycle
- **Descriptive Names**: Use clear test names (can use Japanese)
  ```typescript
  describe('EmailValueObject', () => {
    it('should create valid email', () => { ... })
    it('should reject invalid email format', () => { ... })
    it('正常系_有効なメールアドレスを作成できる', () => { ... })
  })
  ```
- **Refactor When**: Duplication, poor readability, SOLID violations

### Test Types

**Unit Tests** (`tests/unit/`)
- Test domain entities, value objects, use cases in isolation
- Mock external dependencies
- Fast execution

**Integration Tests** (`tests/integration/`)
- Test adapter implementations with real dependencies
- Database integration tests
- External API integration tests

**E2E Tests** (`tests/e2e/`)
- Test complete user flows
- API endpoint testing
- Full system behavior

### Testing Patterns

**Arrange-Act-Assert (AAA)**
```typescript
it('should create user with valid data', () => {
  // Arrange
  const userData = { email: 'test@example.com', name: 'Test User' }

  // Act
  const user = User.create(userData)

  // Assert
  expect(user.email.getValue()).toBe('test@example.com')
})
```

**Given-When-Then (BDD Style)**
```typescript
describe('CreateUserUseCase', () => {
  it('正常系_有効なユーザーデータで新規ユーザーを作成できる', async () => {
    // Given
    const command = new CreateUserCommand('test@example.com', 'Test User')

    // When
    const result = await createUserUseCase.execute(command)

    // Then
    expect(result.isSuccess()).toBe(true)
    expect(result.getValue().email).toBe('test@example.com')
  })
})
```

## Hexagonal Architecture Principles

### Ports and Adapters

**Input Ports (Primary/Driving)**
- Define what the application can do
- Implemented by use cases in application layer
- Called by primary adapters (controllers, CLI, event handlers)

**Output Ports (Secondary/Driven)**
- Define what the application needs from external world
- Interfaces defined in application layer
- Implemented by secondary adapters in infrastructure layer

### Example Structure

```typescript
// Application Layer - Input Port
interface CreateUserUseCase {
  execute(command: CreateUserCommand): Promise<Result<User>>
}

// Application Layer - Output Port
interface UserRepository {
  save(user: User): Promise<Result<void>>
  findByEmail(email: string): Promise<Result<User | null>>
}

// Infrastructure Layer - Input Adapter
@Controller('users')
class UserController {
  constructor(private createUserUseCase: CreateUserUseCase) {}

  @Post()
  async create(@Body() dto: CreateUserDto) {
    const command = new CreateUserCommand(dto.email, dto.name)
    return await this.createUserUseCase.execute(command)
  }
}

// Infrastructure Layer - Output Adapter
class TypeOrmUserRepository implements UserRepository {
  async save(user: User): Promise<Result<void>> {
    // Database implementation
  }

  async findByEmail(email: string): Promise<Result<User | null>> {
    // Database implementation
  }
}
```

### Key Benefits

1. **Testability**: Easy to test business logic in isolation
2. **Flexibility**: Swap implementations without changing core logic
3. **Maintainability**: Clear separation of concerns
4. **Technology Independence**: Business logic not tied to frameworks

### SOLID Principles Integration

- **S**ingle Responsibility: Each layer has one reason to change
- **O**pen/Closed: Open for extension (new adapters), closed for modification
- **L**iskov Substitution: Adapters are substitutable
- **I**nterface Segregation: Ports are focused and minimal
- **D**ependency Inversion: Depend on abstractions (ports), not concretions

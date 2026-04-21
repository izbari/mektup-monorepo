---
name: dotnet-best-practices
description: 'Ensure .NET/C# code meets best practices for the solution/project.'
---

# .NET/C# Best Practices

Ensure .NET/C# code meets the best practices specific to this solution/project.

## Documentation & Structure

- XML documentation comments for all public classes, interfaces, methods, properties
- Include parameter descriptions and return value descriptions
- Follow established namespace structure: `{ProjectName}.{Layer}.{Feature}`

## Design Patterns & Architecture

- Primary constructor syntax for DI: `public class MyClass(IDependency dependency)`
- Interface segregation with clear naming (prefix with 'I')
- Factory pattern for complex object creation
- Repository pattern for data access

## Dependency Injection & Services

- Constructor DI with null checks via `ArgumentNullException.ThrowIfNull`
- Appropriate service lifetimes (Singleton, Scoped, Transient)
- `Microsoft.Extensions.DependencyInjection` patterns
- Service interfaces for testability

## Async/Await Patterns

- `async/await` for all I/O operations
- Return `Task` or `Task<T>` from async methods
- `ConfigureAwait(false)` where appropriate
- Proper async exception handling

## Testing Standards

- xUnit with FluentAssertions
- AAA pattern (Arrange, Act, Assert)
- Moq or NSubstitute for mocking
- Test both success and failure scenarios
- Null parameter validation tests

## Configuration & Settings

- Strongly-typed configuration classes with data annotations
- `IConfiguration` binding
- `appsettings.json` + `appsettings.{Environment}.json`
- Secrets never in source code

## Error Handling & Logging

- Structured logging with `ILogger<T>`
- Scoped logging with meaningful context
- Specific exceptions with descriptive messages
- Global exception handler middleware

## Performance & Security

- .NET 8 / C# 12+ features where applicable
- Input validation and sanitization
- Parameterized queries for database operations
- No sensitive data in logs

## Code Quality

- SOLID principles
- No code duplication — use base classes and utilities
- Meaningful names reflecting domain concepts
- Methods focused and cohesive
- Proper `IDisposable` / `IAsyncDisposable` patterns

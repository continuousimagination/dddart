# DDDart Documentation Index

Complete guide to all DDDart documentation and resources.

## 📚 Core Documentation

### For New Users

1. **[README.md](README.md)**
   - Overview of DDDart features
   - Quick start examples
   - Installation instructions
   - Basic usage patterns

2. **[GETTING_STARTED.md](GETTING_STARTED.md)**
   - 5-minute quick start guide
   - Step-by-step tutorial
   - Common patterns
   - Troubleshooting tips

### For Developers

3. **[DOMAIN_EVENTS_GUIDE.md](DOMAIN_EVENTS_GUIDE.md)**
   - Comprehensive domain events guide
   - Design patterns and best practices
   - Implementation patterns
   - Common scenarios and examples
   - Testing strategies
   - Future remote events architecture

4. **[API_REFERENCE.md](API_REFERENCE.md)**
   - Complete API documentation
   - Class definitions and methods
   - Property descriptions
   - Usage examples for each API
   - Complete working examples

## 📖 Additional Resources

### Examples

5. **[example/EVENTS_README.md](../../example/EVENTS_README.md)**
   - Overview of example code
   - Running the examples
   - Explanation of each example scenario
   - Best practices demonstrated
   - Architecture notes

6. **[example/README.md](../../example/README.md)**
   - General example documentation
   - Serialization examples
   - Running instructions

### Example Code

7. **[example/lib/events_example.dart](../../example/lib/events_example.dart)**
   - Comprehensive working examples
   - 6 different scenarios demonstrated
   - Fully commented code

8. **[example/lib/domain/](../../example/lib/domain/)**
   - Example domain events
   - Example aggregates
   - Real-world domain models

## 🎯 Documentation by Use Case

### "I'm new to DDDart"

Start here:
1. [README.md](README.md) - Get an overview
2. [GETTING_STARTED.md](GETTING_STARTED.md) - Follow the tutorial
3. Run `dart run example/events_main.dart` - See it in action

### "I want to implement domain events"

Follow this path:
1. [GETTING_STARTED.md](GETTING_STARTED.md) - Learn the basics
2. [DOMAIN_EVENTS_GUIDE.md](DOMAIN_EVENTS_GUIDE.md) - Study patterns
3. [example/lib/events_example.dart](../../example/lib/events_example.dart) - See examples
4. [API_REFERENCE.md](API_REFERENCE.md) - Reference as needed

### "I need to look up an API"

Go directly to:
- [API_REFERENCE.md](API_REFERENCE.md) - Complete API docs

### "I want to see working code"

Check out:
1. [example/lib/events_example.dart](../../example/lib/events_example.dart) - Comprehensive examples
2. [example/lib/domain/](../../example/lib/domain/) - Domain models
3. Run `dart run example/events_main.dart` - Execute examples

### "I'm building a specific feature"

Consult:
1. [DOMAIN_EVENTS_GUIDE.md](DOMAIN_EVENTS_GUIDE.md) - Find your pattern
2. [example/lib/events_example.dart](../../example/lib/events_example.dart) - See similar examples
3. [API_REFERENCE.md](API_REFERENCE.md) - API details

### "I'm having issues"

Troubleshoot with:
1. [GETTING_STARTED.md](GETTING_STARTED.md) - Common questions section
2. [DOMAIN_EVENTS_GUIDE.md](DOMAIN_EVENTS_GUIDE.md) - Best practices
3. [example/EVENTS_README.md](../../example/EVENTS_README.md) - Example explanations

## 📋 Documentation by Topic

### Domain Events

- **Overview**: [README.md](README.md) - Core Concepts section
- **Quick Start**: [GETTING_STARTED.md](GETTING_STARTED.md) - Step 1
- **Comprehensive Guide**: [DOMAIN_EVENTS_GUIDE.md](DOMAIN_EVENTS_GUIDE.md) - What are Domain Events?
- **API Details**: [API_REFERENCE.md](API_REFERENCE.md) - DomainEvent section
- **Examples**: [example/lib/domain/](../../example/lib/domain/) - Event classes

### Aggregate Roots

- **Overview**: [README.md](README.md) - Core Concepts section
- **Quick Start**: [GETTING_STARTED.md](GETTING_STARTED.md) - Step 2
- **Patterns**: [DOMAIN_EVENTS_GUIDE.md](DOMAIN_EVENTS_GUIDE.md) - Implementation Patterns
- **API Details**: [API_REFERENCE.md](API_REFERENCE.md) - AggregateRoot section
- **Examples**: [example/lib/domain/user_aggregate.dart](../../example/lib/domain/user_aggregate.dart)

### Event Bus

- **Overview**: [README.md](README.md) - Core Concepts section
- **Quick Start**: [GETTING_STARTED.md](GETTING_STARTED.md) - Step 3
- **Usage Guide**: [README.md](README.md) - Using the Event Bus section
- **API Details**: [API_REFERENCE.md](API_REFERENCE.md) - EventBus section
- **Examples**: [example/lib/events_example.dart](../../example/lib/events_example.dart)

### Event Handlers

- **Patterns**: [README.md](README.md) - Setting Up Event Handlers
- **Best Practices**: [DOMAIN_EVENTS_GUIDE.md](DOMAIN_EVENTS_GUIDE.md) - Event Handlers section
- **Multiple Listeners**: [example/lib/events_example.dart](../../example/lib/events_example.dart) - Multiple Listeners Example
- **Error Handling**: [DOMAIN_EVENTS_GUIDE.md](DOMAIN_EVENTS_GUIDE.md) - Error Handling

### Testing

- **Unit Testing**: [DOMAIN_EVENTS_GUIDE.md](DOMAIN_EVENTS_GUIDE.md) - Testing Events section
- **Integration Testing**: [DOMAIN_EVENTS_GUIDE.md](DOMAIN_EVENTS_GUIDE.md) - Integration Testing
- **Test Examples**: [packages/dddart/test/](test/) - Test files

### Best Practices

- **Quick Reference**: [GETTING_STARTED.md](GETTING_STARTED.md) - Best Practices section
- **Comprehensive Guide**: [DOMAIN_EVENTS_GUIDE.md](DOMAIN_EVENTS_GUIDE.md) - Best Practices section
- **Examples**: [example/EVENTS_README.md](../../example/EVENTS_README.md) - Best Practices section

### Future Features

- **Remote Events**: [DOMAIN_EVENTS_GUIDE.md](DOMAIN_EVENTS_GUIDE.md) - Future: Remote Events section
- **Architecture**: [DOMAIN_EVENTS_GUIDE.md](DOMAIN_EVENTS_GUIDE.md) - Remote Event Transport Interface
- **Migration Path**: [DOMAIN_EVENTS_GUIDE.md](DOMAIN_EVENTS_GUIDE.md) - Migration Path section

## 🔍 Quick Reference

### Common Tasks

| Task | Documentation |
|------|---------------|
| Install DDDart | [README.md](README.md) - Installation |
| Create first event | [GETTING_STARTED.md](GETTING_STARTED.md) - Step 1 |
| Create aggregate | [GETTING_STARTED.md](GETTING_STARTED.md) - Step 2 |
| Set up event bus | [GETTING_STARTED.md](GETTING_STARTED.md) - Step 3 |
| Handle multiple listeners | [README.md](README.md) - Multiple Services Pattern |
| Test events | [DOMAIN_EVENTS_GUIDE.md](DOMAIN_EVENTS_GUIDE.md) - Testing Events |
| Handle errors | [DOMAIN_EVENTS_GUIDE.md](DOMAIN_EVENTS_GUIDE.md) - Error Handling |
| Build workflows | [DOMAIN_EVENTS_GUIDE.md](DOMAIN_EVENTS_GUIDE.md) - Common Scenarios |

### API Quick Links

| API | Documentation |
|-----|---------------|
| DomainEvent | [API_REFERENCE.md](API_REFERENCE.md#domainevent) |
| AggregateRoot | [API_REFERENCE.md](API_REFERENCE.md#aggregateroot) |
| EventBus | [API_REFERENCE.md](API_REFERENCE.md#eventbus) |
| Entity | [API_REFERENCE.md](API_REFERENCE.md#entity) |
| Value | [API_REFERENCE.md](API_REFERENCE.md#value) |
| UuidValue | [API_REFERENCE.md](API_REFERENCE.md#uuidvalue) |

## 📦 Package Structure

```
dddart/
├── packages/dddart/              # Main package
│   ├── README.md                 # Main documentation
│   ├── GETTING_STARTED.md        # Quick start guide
│   ├── DOMAIN_EVENTS_GUIDE.md    # Comprehensive guide
│   ├── API_REFERENCE.md          # API documentation
│   ├── DOCUMENTATION_INDEX.md    # This file
│   ├── lib/                      # Source code
│   │   ├── dddart.dart          # Main export
│   │   └── src/                 # Implementation
│   │       ├── domain_event.dart
│   │       ├── aggregate_root.dart
│   │       ├── event_bus.dart
│   │       ├── entity.dart
│   │       ├── value.dart
│   │       └── uuid_value.dart
│   └── test/                     # Tests
│       ├── domain_event_test.dart
│       ├── aggregate_root_test.dart
│       ├── event_bus_test.dart
│       ├── integration_test.dart
│       └── event_serialization_test.dart
│
└── example/                      # Examples
    ├── EVENTS_README.md          # Example documentation
    ├── README.md                 # General examples
    ├── events_main.dart          # Run domain events examples
    ├── main.dart                 # Run serialization examples
    └── lib/
        ├── events_example.dart   # Example implementation
        └── domain/               # Example domain models
            ├── user_aggregate.dart
            ├── user_registered_event.dart
            ├── order_placed_event.dart
            └── order_shipped_event.dart
```

## 🚀 Getting Started Checklist

- [ ] Read [README.md](README.md) for overview
- [ ] Follow [GETTING_STARTED.md](GETTING_STARTED.md) tutorial
- [ ] Run `dart run example/events_main.dart`
- [ ] Review [example/lib/events_example.dart](../../example/lib/events_example.dart)
- [ ] Read [DOMAIN_EVENTS_GUIDE.md](DOMAIN_EVENTS_GUIDE.md) for patterns
- [ ] Bookmark [API_REFERENCE.md](API_REFERENCE.md) for reference
- [ ] Start building your first event-driven feature!

## 💡 Tips for Using This Documentation

1. **Start with the basics** - Don't skip the getting started guide
2. **Run the examples** - Seeing code in action helps understanding
3. **Reference as needed** - You don't need to memorize everything
4. **Follow patterns** - Use the patterns in the guide as templates
5. **Check examples** - When stuck, look at similar example code
6. **Read incrementally** - You don't need to read everything at once

## 🤝 Contributing to Documentation

If you find issues or want to improve the documentation:

1. Check if the issue is already documented
2. Identify which document needs updating
3. Submit a pull request with improvements
4. Update this index if adding new documents

## 📞 Getting Help

If you can't find what you need:

1. Search all documentation files
2. Check the examples directory
3. Review test files for usage patterns
4. Open an issue on the repository
5. Join community discussions

---

**Last Updated**: November 2024

**Documentation Version**: 1.0.0

**Package Version**: 0.1.0

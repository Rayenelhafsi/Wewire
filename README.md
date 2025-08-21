# Maintenance Communication System

A Windows desktop application for maintenance issue communication between operators, quality agents, and maintenance service personnel.

## Features

- **Role-based access control** for operators, quality agents, and maintenance service
- **Real-time issue reporting** and tracking
- **Chat-based troubleshooting** and communication
- **Machine trouble tracking** and status management
- **Remote assistance** capabilities

## Project Structure

### Core Components
- **Models**: User, Machine, Issue, ChatMessage
- **Screens**: Login, Dashboard (role-based), Chat
- **Navigation**: Role-based routing

### File Structure
```
lib/
├── models/
│   ├── user_model.dart
│   ├── machine_model.dart
│   ├── issue_model.dart
│   └── chat_message_model.dart
├── screens/
│   ├── auth/
│   │   └── login_screen.dart
│   ├── dashboard/
│   │   ├── dashboard_screen.dart
│   │   ├── operator_dashboard.dart
│   │   ├── quality_agent_dashboard.dart
│   │   └── maintenance_dashboard.dart
│   └── chat/
│       └── chat_screen.dart
├── main.dart
└── README.md
```

## Getting Started

1. **Clone the repository**
2. **Install dependencies**:
   ```bash
   flutter pub get
   ```
3. **Run the application**:
   ```bash
   flutter run
   ```

## Features

### Operator Dashboard
- View assigned machines
- Report issues
- Track reported issues

### Quality Agent Dashboard
- Review all issues
- Update issue status
- Communicate with operators

### Maintenance Dashboard
- View assigned issues
- Update issue status
- Communicate with operators and quality agents

### Chat System
- Real-time messaging
- File sharing
- Remote assistance

## Usage

1. **Login** with your role (operator, quality agent, or maintenance service)
2. **Navigate** to your dashboard
3. **Report issues** or **communicate** as needed
4. **Track progress** and **resolve issues**

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

MIT License

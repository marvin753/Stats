# VS Code Configuration

This folder contains VS Code workspace configuration files for the Quiz Stats Animation System.

## Files

### `tasks.json`
Defines all available tasks for building, running, and testing the project.

**Key Tasks:**
- 🍎 **Build & Run macOS App** - Builds the Swift app and runs it
- 🍎 **Clean Build & Run macOS App** - Clean build and run
- 🚀 **Start Backend Server** - Starts the Node.js backend
- 🧪 **Run All Tests** - Runs all test suites
- 🔒 **Run Security Tests** - Runs security-specific tests
- 📦 **Install Dependencies** - Installs npm packages
- ⚙️ **Setup Environment Variables** - Creates .env file
- 🎯 **Quick Start: Full Setup & Run** - Complete setup in one task

### `launch.json`
Defines debugging configurations for:
- Node.js backend debugging
- Jest test debugging
- macOS app debugging (LLDB)

### `settings.json`
Recommended VS Code settings:
- Prettier formatting on save
- ESLint integration
- Swift code formatting
- File exclusions (node_modules, build, etc.)

### `extensions.json`
Recommended VS Code extensions:
- Prettier (code formatter)
- ESLint (linter)
- Swift Language Server
- Docker
- Jest Runner
- Git Lens
- And more...

## How to Use

### 1. Open VS Code

```bash
code /path/to/Stats
```

### 2. Run Tasks

Open Command Palette: **Ctrl+Shift+P** (Windows/Linux) or **Cmd+Shift+P** (Mac)

Search for: **Tasks: Run Task**

Select from the list:
- 🍎 Build & Run macOS App
- 🚀 Start Backend Server
- 🧪 Run All Tests
- etc.

### 3. Use Keyboard Shortcuts

**Quick task shortcut:**
- **Ctrl+Shift+B** (Windows/Linux)
- **Cmd+Shift+B** (Mac)

This runs the default build task: **🍎 Build & Run macOS App**

### 4. Start a New Terminal

VS Code has a built-in terminal. Open it with:
- **Ctrl+`** (Windows/Linux)
- **Cmd+`** (Mac)

Run any task or command manually in the terminal.

## Recommended Workflow

### For Swift Development

1. Open Command Palette → **Tasks: Run Task** → **🎯 Quick Start: Full Setup & Run**
2. Once complete, run **🍎 Build & Run macOS App**
3. Make changes to Swift files
4. Press **Cmd+Shift+B** to rebuild and run

### For Backend Development

1. Open Command Palette → **Tasks: Run Task** → **🚀 Start Backend Server**
2. Server runs in background terminal
3. Use another terminal for running tests: **🧪 Run All Tests**
4. Or debug with **Run and Debug** (F5)

### For Full Stack Development

**Terminal 1:**
```bash
Run: 🚀 Start Backend Server
```

**Terminal 2:**
```bash
Run: 🍎 Build & Run macOS App
```

## Debugging

1. Open VS Code's **Run and Debug** panel (Cmd+Shift+D on Mac)
2. Select configuration:
   - 🚀 Debug Backend (Node.js)
   - 🧪 Debug Tests
   - 🍎 Debug macOS App
3. Press **F5** or click **Start Debugging**

## Environment Setup

Before running any tasks:

1. Copy `.env.example` to `.env`:
   ```bash
   Run: ⚙️ Setup Environment Variables
   ```

2. Edit `.env` with your settings:
   - OPENAI_API_KEY
   - API_KEY (for backend)
   - ALLOWED_DOMAINS
   - etc.

3. Verify setup:
   ```bash
   Run: 📝 Check Environment Setup
   ```

## Quick Reference

| Action | Command |
|--------|---------|
| Build & Run macOS App | Cmd+Shift+B |
| Open Command Palette | Cmd+Shift+P |
| Open Terminal | Cmd+` |
| Start Debugging | F5 |
| Run Current File | Cmd+Alt+J |
| Quick Open | Cmd+P |
| Find in Files | Cmd+Shift+F |

## Installing Recommended Extensions

1. Open Extensions panel (Cmd+Shift+X)
2. View **Workspace Recommended** tab
3. Click "Install All" or install individually

## Troubleshooting

**Tasks not showing up?**
- Reload VS Code (Cmd+Shift+P → Developer: Reload Window)

**Terminal commands not working?**
- Make sure Node.js is installed: `node --version`
- Make sure npm is installed: `npm --version`
- Make sure Xcode is installed: `xcode-select --install`

**Backend not starting?**
- Check if port 3000 is already in use
- Run: 📝 Check Environment Setup
- Check .env file is configured

**Tests failing?**
- Run: 📦 Install Dependencies (both root and backend)
- Run: ⚙️ Setup Environment Variables
- Check backend is running

**macOS app not building?**
- Make sure Xcode is installed
- Run: 🍎 Clean Build & Run macOS App
- Check for Xcode project file exists

## More Information

For detailed information, see:
- `FINAL_VERIFICATION_AND_AUDIT_REPORT.md` - Complete system overview
- `frontend/INTEGRATION_GUIDE.md` - Frontend integration details
- `TESTING_COMPLETE.md` - Testing procedures

---

**Happy coding! 🚀**

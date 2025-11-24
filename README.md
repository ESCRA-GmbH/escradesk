# Escradesk

## 📦 Fork Information

This branch is **forked from** the following repository:

- Original Repository: [rustdesk/rustdesk](https://github.com/rustdesk/rustdesk)

---

## 🛠️ Summary of Changes

Here are some of the changes introduced in this branch compared to the original:

- Installation could be done with config files, which will then be added to the preferences.
- The GUI is added to manage different server connections.
- The program records sessions and session recordings will then be sent to the server automatically.

---

## 📁 How to Use

Clone this repo and build the executable:

- First, create a bridge between rust and flutter, check "When have a problem with bridge.txt" 
- Then: 
```bash
python ./build.py --flutter
```

If only want to see the changes in ui/flutter: 
```bash
cd flutter 
flutter run --release
```

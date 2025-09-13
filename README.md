# easy-dialog
A lightweight Lua library for building and managing interactive dialogs in SA:MP.  
Provides object-oriented APIs to create dialogs, handle navigation, and manage user input in a modular way.

---
## Installation
Place the `easy_dialog` folder in your `lib/` directory (or anywhere in your Lua path).  
Then require it in your script:
```lua
local easy_dialog = require 'easy_dialog'
local Dialog = easy_dialog.Dialog
````
---
## Quick Start
```lua
local d = Dialog.new()
    :setCaption("Hello")
    :setStyle("msgbox")
    :setContent("Welcome to easy-dialog!")
    :setButtons("OK", "")
    :setOnResponse(function(self, button)
        if button == 1 then
            print("Dialog confirmed")
        end
    end)
easy_dialog.init()
easy_dialog.register("welcome", d)
easy_dialog.start("welcome")
```
---
## Main API
### Library Functions
* **`easy_dialog.init()`**
  Starts the dialog handler loop. Must be called before showing dialogs.
* **`easy_dialog.stop()`**
  Stops the dialog handler and closes active dialogs.
* **`easy_dialog.register(name, dialog)`**
  Registers a dialog with a string key for navigation.
* **`easy_dialog.start(name, data?)`**
  Starts a registered dialog as root. Clears navigation stack.
* **`easy_dialog.go(name, data?)`**
  Navigates to another registered dialog. Keeps navigation stack.
* **`easy_dialog.done(result?)`**
  Ends the current dialog and passes a result back to the parent dialog.
* **`easy_dialog.back()`**
  Goes back to the previous dialog in the stack.
* **`easy_dialog.home()`**
  Returns to the first/root dialog.
* **`easy_dialog.show(dialog, isTemporary?, resetPagination?)`**
  Directly shows a dialog object (registered or not).
* **Quick helpers**:
  * `easy_dialog.alert(caption, text, onOK?)`
  * `easy_dialog.confirm(caption, text, onConfirm)`
  * `easy_dialog.prompt(caption, text, onInput)`
---
### Dialog Methods
* **Creation**: `Dialog.new()`
  Returns a new dialog object.
* **Setters** (chainable):
  * `:setId(id)` – set custom dialog ID (optional).
  * `:setCaption(textOrFunc)` – set title/caption.
  * `:setStyle(style)` – one of: `msgbox`, `input`, `list`, `password`, `tablist`, `tablist_headers`.
  * `:setButtons(okText, cancelText)` – set button labels.
  * `:setContent(textOrFunc)` – set dialog text (non-list styles).
  * `:setHeaders(headers)` – table of tablist headers.
  * `:setItems(itemsOrFunc)` – set list/tablist items.
  * `:setItemsPerPage(n)` – enable pagination for lists.
* **Callbacks**:
  * `:setOnStart(func(self, data))` – called when dialog is first shown.
  * `:setOnShow(func(self))` – called when dialog becomes active.
  * `:setOnUpdate(func(self, deltaTime))` – called every frame while active.
  * `:setOnResponse(func(self, button, index, input, item))` – called when user responds.
  * `:setOnProcessResult(func(self, result))` – called when returning from child dialog.
* **Other methods**:
  * `:setLaunchMode(mode)` – one of `STANDARD`, `ROOT`, `SINGLE_TOP`.
  * `:update()` – force re-render current dialog.
  * `:close(button?)` – close dialog programmatically.
---
## Navigation Modes
* **`STANDARD`** – normal stack behavior.
* **`ROOT`** – clears the stack when entered.
* **`SINGLE_TOP`** – avoids pushing duplicate instances onto stack.
---
## Configuration
You can customize default texts via:
```lua
easy_dialog.configure({
    PAGINATION_TEXT = "Page %d/%d",
    EMPTY_LIST_TEXT = "{CCCCCC}Empty list.",
    PAGINATION_PREV = "{BDBDBD}<< Back",
    PAGINATION_NEXT = "{BDBDBD}Next >>"
})
```
---
## Example
```lua
local mainMenu = Dialog.new()
    :setLaunchMode(easy_dialog.LaunchMode.ROOT)
    :setCaption("Main Menu")
    :setStyle("list")
    :setItems({"Option A", "Option B"})
    :setButtons("Select", "Close")
    :setOnResponse(function(self, button, index)
        if button == 1 and index == 1 then
            easy_dialog.alert("Info", "You chose option A")
        elseif button == 1 and index == 2 then
            easy_dialog.confirm("Confirm", "Are you sure?", function(ok)
                print("Confirmed:", ok)
            end)
        end
    end)
easy_dialog.init()
easy_dialog.register("main", mainMenu)
easy_dialog.start("main")
```

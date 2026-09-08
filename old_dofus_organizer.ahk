#Requires AutoHotkey v2.0

SetTitleMatchMode(2)

F1::{
    if WinExist("Kaska-yopette")
        WinActivate()
    if WinExist("Douanopuncture")
        WinActivate()
}

F2::{
    if WinExist("Kaska-nini")
        WinActivate()
    if WinExist("Clandestin")
        WinActivate()
}

F3::{
    if WinExist("Kaska-sadi")
        WinActivate()
    if WinExist("Pasdevisa")
        WinActivate()
}

F4::{
    if WinExist("Kaska-panda")
        WinActivate()
    if WinExist("Oqtf")
        WinActivate()
}

F12::ExitApp()

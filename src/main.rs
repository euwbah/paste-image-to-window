use clipboard_rs::common::RustImage;
use clipboard_rs::{Clipboard, ClipboardContext};
use show_image::{create_window, event::WindowEvent, ImageInfo, ImageView, WindowOptions};
use std::thread;
use winapi::shared::minwindef::UINT;
use winapi::um::winuser::{
    GetAsyncKeyState, RegisterHotKey, UnregisterHotKey, MOD_ALT, MOD_CONTROL, MOD_NOREPEAT, MOD_WIN, VK_F16, VK_F2
};
use winreg::enums::*;
use winreg::RegKey;

#[show_image::main]
fn main() {
    const KEY1: i32 = VK_F16;
    const KEY1_MODIFIERS: isize = 0;

    const KEY2: i32 = VK_F2;
    const KEY2_MODIFIERS: isize = MOD_WIN;

    // Set up hotkey
    unsafe {
        let res = RegisterHotKey(
            // This registers F16 (function key 16):
            std::ptr::null_mut(),
            1, // hotkey id can be the same for all.
            (KEY1_MODIFIERS | MOD_NOREPEAT) as UINT, // NOREPEAT: don't spam if the key is held down
            KEY1 as UINT,
        ) & RegisterHotKey(
            // This registers Windows Key + F2:
            std::ptr::null_mut(),
            1,
            (KEY2_MODIFIERS | MOD_NOREPEAT) as UINT, // MOD_WIN: windows key modifier
            KEY2 as UINT,
        );

        if res == 0 {
            println!("Failed to register hotkey(s). Exiting.");
            return;
        }
    }

    loop {
        unsafe {
            // The MSB of a SHORT is 2^15 = 0x8000, which is the bit that indicates if the key is
            // pressed. The LSB of a SHORT is 2^0 = 0x0001, which is the bit that indicates if the
            // key was pressed since the last call to GetAsyncKeyState. However, the latter is less
            // reliable, so we have our own check to prevent multiple triggers.
            if (GetAsyncKeyState(KEY1) | GetAsyncKeyState(KEY2)) as u16 & 0x8000 != 0 {
                thread::spawn(|| {
                    handle_f16_press();
                });
                // prevent multiple triggers from one press.
                while (GetAsyncKeyState(KEY1) | GetAsyncKeyState(KEY2)) as u16 & 0x8000 != 0 {
                    std::thread::sleep(std::time::Duration::from_millis(20));
                }
            }
        }
        std::thread::sleep(std::time::Duration::from_millis(100)); // Reduce CPU usage
    }

    // In case the loop above exits, clean up the hotkey.
    #[allow(unreachable_code)]
    unsafe {
        UnregisterHotKey(std::ptr::null_mut(), 1);
    }
}

fn handle_f16_press() {
    let clip_ctx = if let Ok(c) = ClipboardContext::new() {
        c
    } else {
        println!("Failed to create clipboard context.");
        return;
    };
    if let Ok(image) = clip_ctx.get_image() {
        let rgba8 = if let Ok(x) = image.to_rgba8() {
            x
        } else {
            println!("Failed to convert clipboard image to RGBA8.");
            return;
        };
        let width = rgba8.width();
        let height = rgba8.height();

        let image = ImageView::new(ImageInfo::rgba8(width, height), &rgba8);

        let mut window = if let Ok(mut window) = create_window(
            "Clipboard Image",
            WindowOptions::new()
                .set_borderless(false)
                .set_show_overlays(false)
                .set_size([width, height])
                .set_default_controls(true)
                .set_resizable(true)
                .set_start_hidden(false)
                .set_preserve_aspect_ratio(true),
        ) {
            window
        } else {
            println!("Failed to create window.");
            return;
        };
        window.set_image("clipboard_image", image).unwrap();

        for event in window.event_channel().unwrap().iter() {
            if let WindowEvent::CloseRequested(e) = event {
                break;
            }
        }
    } else {
        println!("Failed to get image from clipboard.");
    }
}

"""Read paired Watch UDIDs through the existing USB trust relationship.

No Apple Account login, signing, app installation, certificate change or network upload.
Device identifiers are shown locally and never written to a report.
"""
import asyncio
import re
import sys


def identifiers(value):
    result = set()
    if isinstance(value, str) and re.fullmatch(r'(?:[0-9a-fA-F]{40}|[0-9a-fA-F]{8}-[0-9a-fA-F]{16})', value):
        result.add(value)
    elif isinstance(value, dict):
        for child in value.values():
            result.update(identifiers(child))
    elif isinstance(value, list):
        for child in value:
            result.update(identifiers(child))
    return sorted(result)


async def read_watch():
    from pymobiledevice3.usbmux import list_devices
    from pymobiledevice3.lockdown import create_using_usbmux
    from pymobiledevice3.services.companion import CompanionProxyService

    devices = [device for device in await list_devices() if device.connection_type == 'USB']
    if len(devices) != 1:
        raise RuntimeError('iPhoneを1台だけUSB接続し、ロック解除・PCへの信頼を確認してください。')
    lockdown = await create_using_usbmux(serial=devices[0].serial, autopair=False, connection_type='USB')
    try:
        if not lockdown.paired:
            raise RuntimeError('このPCへの信頼がありません。iPhoneで「信頼」を済ませてください。')
        async with CompanionProxyService(lockdown) as service:
            watches = identifiers(await service.list())
        if not watches:
            raise RuntimeError('Watchが見つかりません。Watchのロックを解除し、iPhoneとの接続を確認してください。')
        return watches
    finally:
        await lockdown.close()


def self_test():
    sample = '00000000-0000000000000001'
    assert identifiers({'PairedDevicesArray': [sample, {'UDID': sample}, {'serial': 'SERIAL123'}]}) == [sample]
    assert identifiers({'secret': b'not text', 'unrelated': '12345'}) == []
    assert identifiers(['a'*40]) == ['a'*40]
    # Verify frozen dependency imports without connecting to a device.
    from pymobiledevice3.services.companion import CompanionProxyService
    from pymobiledevice3.lockdown import create_using_usbmux
    assert callable(create_using_usbmux) and hasattr(CompanionProxyService, 'list')
    print('WatchInfo parser and dependency imports passed; no device accessed')


def main():
    import tkinter as tk
    from tkinter import ttk
    from concurrent.futures import ThreadPoolExecutor

    window = tk.Tk()
    window.title('Fairway — Watch情報（読み取りのみ）')
    window.geometry('650x340')
    frame = ttk.Frame(window, padding=20); frame.pack(fill='both', expand=True)
    ttk.Label(frame, text='iPhoneをUSB接続し、iPhoneとWatchのロックを解除してください。', wraplength=600).pack(anchor='w')
    ttk.Label(frame, text='Apple Accountの入力は不要です。WatchのUDIDだけを読み取ります。', wraplength=600).pack(anchor='w', pady=10)
    output = tk.Text(frame, height=6, wrap='word'); output.pack(fill='both', expand=True)
    executor = ThreadPoolExecutor(max_workers=1)
    def display(text):
        output.delete('1.0', 'end'); output.insert('1.0', text)
    def query():
        button.configure(state='disabled'); display('確認中…')
        future = executor.submit(lambda: asyncio.run(asyncio.wait_for(read_watch(), timeout=30)))
        def poll():
            if not future.done():
                window.after(100, poll); return
            button.configure(state='normal')
            try: display('\n'.join(future.result()) + '\n\nこの値をSideStoreの「Watch対応」に入力してください。\n端末IDなので公開しないでください。')
            except Exception as error:
                # Never dump pairing records or arbitrary protocol response payloads.
                detail = str(error) if isinstance(error, RuntimeError) else type(error).__name__
                display('読み取れませんでした。\n' + detail + '\n\n既存iloaderを閉じ、USB接続・ロック解除・信頼を確認してください。')
        window.after(100, poll)
    button = ttk.Button(frame, text='WatchのUDIDを表示', command=query); button.pack(anchor='w', pady=12)
    window.mainloop()
    executor.shutdown(wait=False, cancel_futures=True)


if __name__ == '__main__':
    if '--self-test' in sys.argv:
        self_test()
    else:
        main()

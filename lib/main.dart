import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:ui';
import 'package:ffi/ffi.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as path;
import 'package:tray_manager/tray_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:walli/FancyButton.dart';
import 'package:window_manager/window_manager.dart';
import 'package:windows_single_instance/windows_single_instance.dart';
import 'package:system_theme/system_theme.dart';


void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await WindowsSingleInstance.ensureSingleInstance(
      args,
      "walli",
      onSecondWindow: (args) async {
        if(await windowManager.isVisible()){
          await windowManager.center(animate: true);
        }else{
          await windowManager.show();
          await windowManager.center();
          await windowManager.focus();
        }
        print(args);
      });
  await windowManager.ensureInitialized();
  Directory directory = await getApplicationDocumentsDirectory();
  if(!await Directory('${directory.path}/walli').exists()){
    directory = await Directory('${directory.path}/walli').create();
  }else{
    directory = Directory('${directory.path}/walli');
  }
  Hive.init(directory.path);
  Hive.openBox('setting');
  const windowOptions = WindowOptions(
    size: Size(400,650),
    minimumSize: Size(400,650),
    maximumSize: Size(400,650),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
    fullScreen: false,
    windowButtonVisibility: false,
  );
  await windowManager.waitUntilReadyToShow(windowOptions);
  await windowManager.setPreventClose(true);

  await trayManager.setIcon('assets/walli.ico');
  int selectedTime = await Hive.box('setting').get('timer',defaultValue: 0);
  await setTray();
  trayManager.addListener(TrayApp());

  launchAtStartup.setup(
    appName: 'Walli',
    appPath: Platform.resolvedExecutable,
    packageName: 'com.taheri.walli',
  );
  await launchAtStartup.enable();

  if(selectedTime != 0){
    scheduleWallpaperChange(Duration(seconds: selectedTime));
  }
  await SystemTheme.accentColor.load();
  runApp(MyApp());
  Future.delayed(const Duration(seconds: 1),() async{
    await windowManager.center(animate: true);
    await windowManager.hide();
  });
}
setTray() async {
  int selectedTime = await Hive.box('setting').get('timer',defaultValue: 0);
  await trayManager.setContextMenu(Menu(items: [
    MenuItem(label: 'Open', key: 'open'),
    MenuItem.submenu(
        label: 'Change Wallpaper',
        submenu: Menu(
            items: [
              MenuItem(
                  label: 'Change Now',
                  key: 'now'
              ),
              MenuItem.checkbox(
                  checked: selectedTime == 350,
                  label: 'Change Every 5 Minutes',
                  key: 't350'
              ),
              MenuItem.checkbox(
                  checked: selectedTime == 600,
                  label: 'Change Every 10 Minutes',
                  key: 't600'
              ),
              MenuItem.checkbox(
                  checked: selectedTime == 900,
                  label: 'Change Every 15 Minutes',
                  key: 't900'
              ),
              MenuItem.checkbox(
                  checked: selectedTime == 1800,
                  label: 'Change Every 30 Minutes',
                  key: 't1800'
              ),
              MenuItem.checkbox(
                  checked: selectedTime == 3600,
                  label: 'Change Every 1 Hour',
                  key: 't3600'
              ),
              MenuItem.checkbox(
                  checked: selectedTime == 0,
                  label: 'Disabled',
                  key: 'disable'
              ),
            ]
        )
    ),
    MenuItem.separator(),
    MenuItem(label: 'Exit', key: 'exit'),
  ]));
}
Timer? wallpaperTimer;

class TrayApp with TrayListener {

  @override
  void onTrayIconMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  Future<void> onTrayMenuItemClick(MenuItem menuItem) async {
    if (menuItem.key == 'now') {
      scheduleWallpaperChange(const Duration(seconds: 0));
    }
    else if (menuItem.key!.startsWith('t')) {
      String input = menuItem.key!.substring(1);
      int parsedInt = int.tryParse(input)!;
      Hive.box('setting').put('timer',parsedInt);
      scheduleWallpaperChange(Duration(seconds: parsedInt));
    }else if (menuItem.key == 'open') {
      await windowManager.setSize(const Size(400,650));
      await windowManager.show();
      await windowManager.focus();
    } else if (menuItem.key == 'disable') {
      Hive.box('setting').put('timer',0);
      wallpaperTimer?.cancel();
    } else if (menuItem.key == 'exit') {
      trayManager.destroy();
      exit(0);
    }
    await setTray();
  }


}
Future<void> scheduleWallpaperChange(Duration interval) async {
  if(interval.inSeconds >0){
    wallpaperTimer?.cancel();
    wallpaperTimer = Timer.periodic(interval, (Timer t) async {
      // Size size = await windowManager.getSize();
      Directory directory = await getApplicationDocumentsDirectory();
      directory = Directory(path.join(directory.path,'walli'));
      File next = File(path.join(directory.path,'next.jpg'));
      File background = File(path.join(directory.path,'background.jpg'));

      if(await next.exists()){
        if(await background.exists()){
          await background.delete();
        }
        next.rename(background.path);
        setWallpaper(background.path);
        await downloadImage('https://picsum.photos/3840/2160?random',name: 'next.jpg');
      }else{
        File image = await downloadImage('https://picsum.photos/3840/2160?random');
        setWallpaper(image.path);
        File imageNext = await downloadImage('https://picsum.photos/3840/2160?random',name: 'next.jpg');
      }
    });
  }else{
    Directory directory = await getApplicationDocumentsDirectory();
    directory = Directory(path.join(directory.path,'walli'));
    File next = File(path.join(directory.path,'next.jpg'));
    File background = File(path.join(directory.path,'background.jpg'));

    if(await next.exists()){
      if(await background.exists()){
        await background.delete();
      }
      next.rename(background.path);
      setWallpaper(background.path);
      await downloadImage('https://picsum.photos/3840/2160?random',name: 'next.jpg');
    }else{
      File image = await downloadImage('https://picsum.photos/3840/2160?random');
      setWallpaper(image.path);
      File imageNext = await downloadImage('https://picsum.photos/3840/2160?random',name: 'next.jpg');
    }
  }

}

Future<File> downloadImage(String url,{String name='background.jpg'}) async {
  final response = await http.get(Uri.parse(url));
  Directory directory = await getApplicationDocumentsDirectory();
  if(!await Directory('${directory.path}/walli').exists()){
    directory = await Directory('${directory.path}/walli').create();
  }else{
    directory = Directory('${directory.path}/walli');
  }
  final filePath = '${directory.path}/$name';
  final file = File(filePath);
  await file.writeAsBytes(response.bodyBytes);
  return file;
}
typedef SystemParametersInfoC = ffi.Int32 Function(ffi.Uint32 uiAction, ffi.Uint32 uiParam, ffi.Pointer<Utf16> pvParam, ffi.Uint32 fWinIni);
typedef SystemParametersInfoDart = int Function(int uiAction, int uiParam, ffi.Pointer<Utf16> pvParam, int fWinIni);
void setWallpaper(String filePath) {


  const SPI_SETDESKWALLPAPER = 0x0014;
  const UPDATE_INI_FILE = 0x01;
  const SEND_CHANGE = 0x02;

  final user32 = ffi.DynamicLibrary.open('user32.dll');
  final systemParametersInfo = user32
      .lookupFunction<SystemParametersInfoC, SystemParametersInfoDart>(
      'SystemParametersInfoW');

  final filePathPointer = filePath.toNativeUtf16();
  systemParametersInfo(SPI_SETDESKWALLPAPER, 0, filePathPointer, UPDATE_INI_FILE | SEND_CHANGE);
  calloc.free(filePathPointer);
}

class MyApp extends StatefulWidget{
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WindowListener  {
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
  }

  @override
  void onWindowClose() {
    windowManager.hide();
  }

  @override
  Widget build(BuildContext context) {
    return SystemThemeBuilder(builder: (context, accent) {
      return MaterialApp(
        title: 'Walli',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: accent.accent),
          useMaterial3: true,
        ),
        home: Scaffold(
          body: SafeArea(
            child: Container(
              child: Column(
                children: [
                  GestureDetector(
                    onPanStart: (details) async {
                      await windowManager.startDragging();
                    },
                    onDoubleTap: (){
                      windowManager.center(animate: true);
                    },
                    child: Container(
                      height: Theme.of(context).bottomAppBarTheme.height,
                      decoration: BoxDecoration(
                        color: accent.accent,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Drag Area
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10.0),
                              child: Row(
                                children: [
                                  Image.asset('assets/walli.png',width: 25,),
                                  SizedBox(width: 5),
                                  Text(
                                    'Walli',
                                    style: TextStyle(color: Colors.white70, fontSize: 18),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Window Control Buttons
                          Row(
                            children: [
                              // Close Button
                              IconButton(
                                icon: Icon(Icons.close, color: Colors.white70),
                                onPressed: () async {
                                  await windowManager.close();
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset('assets/walli.png',width: 250,),
                      SizedBox(height: 20,),
                      Text('Walli',style: TextStyle(fontSize: 32,fontWeight: FontWeight.bold,color: accent.accent),textAlign: TextAlign.center,),
                      Text('Made By Hossein Laletaheri',style: TextStyle(fontSize: 22,fontWeight: FontWeight.bold),textAlign: TextAlign.center,),
                      SizedBox(height: 30,),
                      Text('Check Tray Menu!!',style: TextStyle(fontSize: 16),textAlign: TextAlign.center,)
                    ],
                  )),
                  Container(
                    padding: EdgeInsets.all(15),
                    // height: 100,
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: FancyButton(
                              onPressed: (){
                                scheduleWallpaperChange(const Duration(seconds: 0));
                              },
                              size: 50,
                              color: accent.accent,
                              child: Text('Change Now',style: TextStyle(fontWeight: FontWeight.bold,fontSize: 22,color: Theme.of(context).colorScheme.onPrimary),)
                          ),
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });

  }
}

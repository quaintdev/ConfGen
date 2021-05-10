import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart';

import 'package:flutter/material.dart';

void main() {
  runApp(App());
}

class App extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Configuration Generator',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MainPage(title: 'Configuration Generator'),
    );
  }
}

class MainPage extends StatefulWidget {
  MainPage({Key key, this.title}) : super(key: key);
  final String title;

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  TextEditingController ctrlService = TextEditingController();
  Config c;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        padding: EdgeInsets.all(16.0),
        child: Row(
          children: [
            LimitedBox(
              maxWidth: 300.0,
              child: c == null
                  ? CircularProgressIndicator()
                  : SingleChildScrollView(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.start,
                        runSpacing: 16.0,
                        children: [
                          DropdownButtonFormField<String>(
                              items: availableConfigs.keys
                                  .map<DropdownMenuItem<String>>(
                                      (String value) {
                                return DropdownMenuItem<String>(
                                    value: value, child: Text(value));
                              }).toList(),
                              isExpanded: true,
                              value: c.filename,
                              decoration:
                                  InputDecoration(border: OutlineInputBorder()),
                              hint: Text("Choose config"),
                              onChanged: (String value) {
                                if (c != null) {
                                  if (c.filename == value) return;
                                  c = Config(filename: value);
                                  c.load().then((result) {
                                    if (result) {
                                      c.loadWidgets();
                                      setState(() {});
                                    }
                                  });
                                }
                              }),
                          for (var widget in c.widgetList) widget,
                          c.widgetList.length == 0
                              ? Container()
                              : ButtonBar(
                                  children: [
                                    TextButton(
                                        onPressed: () {
                                          setState(() {
                                            ctrlService.text = c.update();
                                          });
                                        },
                                        child: Text("Create")),
                                    TextButton(
                                        onPressed: () {
                                          c.entityWidgetList.forEach((widget) {
                                            widget.controller.text = "";
                                          });
                                        },
                                        child: Text("Reset")),
                                  ],
                                )
                        ],
                      ),
                    ),
            ),
            VerticalDivider(),
            Expanded(
              child: Container(
                padding: EdgeInsets.all(16.0),
                width: 500.0,
                alignment: Alignment.topLeft,
                child: TextField(
                    keyboardType: TextInputType.multiline,
                    controller: ctrlService,
                    maxLines: null,
                    decoration: InputDecoration.collapsed(
                        hintText:
                            "Your configuration file contents will be shown here")),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    loadAvailableConfigs().then((value) {
      if (true) {
        c = Config(filename: "systemd");
        c.load().then((result) {
          if (result) {
            c.loadWidgets();
            setState(() {});
          }
        });
      }
    });
  }

  Map<String, bool> availableConfigs = HashMap();

  Future<bool> loadAvailableConfigs() async {
    var dir = Directory("configs/");
    Stream<FileSystemEntity> entityList =
        dir.list(recursive: false, followLinks: false);
    await for (FileSystemEntity entity in entityList)
      availableConfigs.putIfAbsent(
          basename(entity.path).split(".")[0], () => false);
    return true;
  }
}

class Config {
  String filename;
  List<String> contentAsLines;

  String jsonConfig;
  List<EntityWidget> entityWidgetList = [];
  Map<String, TextEditingController> controllerMap = HashMap();
  List<Widget> widgetList = [];

  Config({this.filename});

  Future<bool> load() async {
    contentAsLines =
        await File("configs/" + this.filename + ".conf").readAsLines();
    jsonConfig = await File("configs/" + filename + ".json").readAsString();
    return true;
  }

  void loadWidgets() async {
    jsonDecode(jsonConfig).forEach((item) {
      EntityWidget entityWidget = EntityWidget.fromJson(item);
      widgetList.add(entityWidget.getWidget());
      controllerMap.putIfAbsent(entityWidget.id, () => entityWidget.controller);
      entityWidgetList.add(entityWidget);
    });
  }

  String update() {
    String updatedText = "";
    for (String line in contentAsLines) {
      if (line.contains("<")) {
        String parameter = line.split("<")[1].split(">")[0];
        if (controllerMap.containsKey(parameter)) {
          line = line.replaceAll(
              "<" + parameter + ">", controllerMap[parameter].text);
        } else {
          line = "";
        }
      }
      updatedText = updatedText + line + "\n";
    }
    return updatedText;
  }
}

class EntityWidget {
  String type, label, id, tooltip;
  List<String> values = [];
  TextEditingController controller = TextEditingController();

  EntityWidget({this.type, this.label, this.id, this.values, this.tooltip});

  EntityWidget.fromJson(Map<String, dynamic> json) {
    type = json["Type"];
    label = json["Label"];
    id = json["ID"];
    tooltip= json["Tooltip"];
    if (json["Values"] != null)
      json["Values"].forEach((item) => values.add(item.toString()));
  }

  Widget getWidget() {
    switch (type) {
      case "Text":
        return Text(label, style: TextStyle(fontSize: 24.0));
      case "TextField":
        return Tooltip(
          message: tooltip!=null?tooltip:label,
          child: TextFormField(
            controller: controller,
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              labelText: label,
            ),
          ),
        );
      case "DropdownMenuButton":
        return DropdownButtonFormField<String>(
            items: values.map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(value: value, child: Text(value));
            }).toList(),
            isExpanded: true,
            decoration: InputDecoration(border: OutlineInputBorder()),
            hint: Text(label),
            onChanged: (String value) {
              controller.text = value;
            });
    }
    return null;
  }
}

import 'package:flutter/material.dart';

// const sidebarColor = Color.fromARGB(255, 182, 159, 28); //COLORWARNING WHEN showing titlebar widget...
// const backgroundStartColor = Color(0xFF0583EA);
// const backgroundEndColor = Color(0xFF0697EA);

const sidebarColor = Color.fromARGB(255, 182, 159, 28); //COLORWARNING WHEN showing titlebar widget...
const backgroundStartColor = Color.fromARGB(255, 182, 159, 28);
const backgroundEndColor = Color.fromARGB(255, 182, 159, 28); // CHANGED HERE

class DesktopTitleBar extends StatelessWidget {
  final Widget? child;

  const DesktopTitleBar({Key? key, this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [backgroundStartColor, backgroundEndColor],
            stops: [0.0, 1.0]),
      ),
      child: Row(
        children: [
          Expanded(
            child: child ?? Offstage(),
          )
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/foundation.dart';

class ChatAgenteScreen extends StatefulWidget {
  const ChatAgenteScreen({super.key});

  @override
  State<ChatAgenteScreen> createState() => _ChatAgenteScreenState();
}

class _ChatAgenteScreenState extends State<ChatAgenteScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController();

    // ESCUDO: Agrupamos TODAS las configuraciones que son solo para celulares acá
    if (!kIsWeb) {
      _controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      _controller.setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          },
        ),
      );
    } else {
      // Si estamos en la Web (Chrome), sacamos el circulito de carga después de 2 segundos
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      });
    }

    // ⚠️ REEMPLAZÁ ESTE LINK POR EL ENLACE PÚBLICO DE TU AGENTE
    _controller.loadRequest(Uri.parse('https://app.relevanceai.com/agents/bcbe5a/dee8f2e4-241d-4ce4-9140-a5456e24c540/b99fb88f-743d-4a10-81f4-b7d5af7b6a23/embed-chat?hide_tool_steps=false&hide_file_uploads=false&hide_conversation_list=false&bubble_style=agent&primary_color=%23685FFF&bubble_icon=pd%2Fchat&input_placeholder_text=Type+your+message...&hide_logo=false&hide_description=false'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Asistente IA"),
        elevation: 0,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),

          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}
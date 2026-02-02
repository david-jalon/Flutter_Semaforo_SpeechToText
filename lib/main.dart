import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

void main() => runApp(
    const MaterialApp(home: SemaforoApp(), debugShowCheckedModeBanner: false));

class SemaforoApp extends StatefulWidget {
  const SemaforoApp({super.key});

  @override
  State<SemaforoApp> createState() => _SemaforoAppState();
}

class _SemaforoAppState extends State<SemaforoApp>
    with SingleTickerProviderStateMixin {
  final SpeechToText _speech = SpeechToText();
  bool _isListening = false;
  bool _speechEnabled = false;
  bool _userStopped = true;
  String _transcripcion = "Presiona el botón para hablar...";

  final Color _colorNeutro = Colors.blueGrey[800]!;
  late Color _colorSemaforo;

  bool _modoFiesta = false;
  Timer? _timerFiesta;

  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _colorSemaforo = _colorNeutro;
    _initVoice();
    _initAnimation();
  }

  void _initVoice() async {
    _speechEnabled = await _speech.initialize(
      onStatus: (status) {
        if ((status == 'done' || status == 'notListening') && !_userStopped) {
          _rearrancarMicro();
        }
      },
      onError: (val) => print('Error: $val'),
    );
    setState(() {});
  }

  void _rearrancarMicro() {
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!_userStopped) _activarEscucha();
    });
  }

  void _initAnimation() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _animation =
        Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);
  }

  void _procesarComando(String texto) {
    if (_userStopped) return;
    String comando = texto.toLowerCase();

    int idxVerde = comando.lastIndexOf("verde");
    int idxAmarillo = comando.lastIndexOf("amarillo");
    int idxRojo = comando.lastIndexOf("rojo");
    int idxFiesta = comando.lastIndexOf("fiesta");

    int maxIdx = [idxVerde, idxAmarillo, idxRojo, idxFiesta].reduce(max);
    if (maxIdx != -1 && maxIdx != idxFiesta && _modoFiesta) _detenerFiesta();
    if (maxIdx == -1) return;

    setState(() {
      if (maxIdx == idxVerde)
        _colorSemaforo = Colors.greenAccent[700]!;
      else if (maxIdx == idxAmarillo)
        _colorSemaforo = Colors.yellowAccent[700]!;
      else if (maxIdx == idxRojo)
        _colorSemaforo = Colors.redAccent[700]!;
      else if (maxIdx == idxFiesta) _iniciarFiesta();
    });
  }

  void _iniciarFiesta() {
    if (_modoFiesta) return;
    _modoFiesta = true;
    _timerFiesta = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      setState(() {
        _colorSemaforo =
            Color((Random().nextDouble() * 0xFFFFFF).toInt()).withOpacity(1.0);
      });
    });
  }

  void _detenerFiesta() {
    _modoFiesta = false;
    _timerFiesta?.cancel();
  }

  void _activarEscucha() async {
    if (_userStopped) return;
    await _speech.listen(
      localeId: 'es_ES',
      onResult: (result) {
        if (!_userStopped) {
          setState(() {
            _transcripcion = result.recognizedWords;
            _procesarComando(result.recognizedWords);
          });
        }
      },
    );
  }

  void _toggleEscucha() async {
    if (!_isListening) {
      if (_speechEnabled) {
        setState(() {
          _userStopped = false;
          _isListening = true;
          _transcripcion = "";
        });
        _activarEscucha();
      }
    } else {
      _userStopped = true;
      await _speech.stop();
      _detenerFiesta();
      setState(() {
        _isListening = false;
        _colorSemaforo = _colorNeutro;
        _transcripcion = "Presiona el botón para hablar...";
      });
    }
  }

  @override
  void dispose() {
    _timerFiesta?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
          title: const Text("Semáforo Inteligente"),
          backgroundColor: Colors.black),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 450),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // El semáforo animado
              AnimatedBuilder(
                animation: _animation,
                builder: (context, child) => Container(
                  width: 230,
                  height: 230,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: _colorSemaforo.withOpacity(0.4),
                          blurRadius: 40 * _animation.value + 20,
                          spreadRadius: 10)
                    ],
                  ),
                  child: child,
                ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  decoration: BoxDecoration(
                      color: _colorSemaforo,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 6)),
                  child: const Icon(Icons.lightbulb_outline,
                      size: 80, color: Colors.white70),
                ),
              ),
              const SizedBox(height: 50),
              // Indicador de micro
              Text(_isListening ? "• ESCUCHANDO..." : "MICRO APAGADO",
                  style: TextStyle(
                      color:
                          _isListening ? Colors.greenAccent : Colors.redAccent,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              // Cuadro de texto
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(15)),
                child: Text(_transcripcion,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 18)),
              ),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _toggleEscucha,
        backgroundColor: _isListening ? Colors.redAccent : Colors.purpleAccent,
        label: Text(_isListening ? "DETENER" : "COMENZAR"),
        icon: Icon(_isListening ? Icons.stop : Icons.mic),
      ),
    );
  }
}

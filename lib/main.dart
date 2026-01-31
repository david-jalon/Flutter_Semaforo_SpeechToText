import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

void main() => runApp(
  const MaterialApp(home: SemaforoApp(), debugShowCheckedModeBanner: false),
);

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
    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_animationController);
  }

  void _procesarComando(String texto) {
    if (_userStopped) return; // Si el usuario detuvo, no procesamos más

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
      else if (maxIdx == idxFiesta)
        _iniciarFiesta();
    });
  }

  void _iniciarFiesta() {
    if (_modoFiesta) return;
    _modoFiesta = true;
    _timerFiesta = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      setState(() {
        _colorSemaforo = Color(
          (Random().nextDouble() * 0xFFFFFF).toInt(),
        ).withOpacity(1.0);
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
      listenFor: const Duration(minutes: 1),
      pauseFor: const Duration(seconds: 20),
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
      // RESET TOTAL
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
        title: const Text(
          "Semáforo",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 450),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _colorSemaforo.withOpacity(
                            0.5 * _animation.value + 0.2,
                          ),
                          blurRadius: 40 + (20 * _animation.value),
                          spreadRadius: 10 + (5 * _animation.value),
                        ),
                      ],
                    ),
                    child: child,
                  );
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  decoration: BoxDecoration(
                    color: _colorSemaforo,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 6),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.lightbulb_outline,
                      size: 80,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 50),
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 20,
                ),
                decoration: BoxDecoration(
                  color: _isListening
                      ? Colors.green.withOpacity(0.2)
                      : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: _isListening ? Colors.greenAccent : Colors.white10,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isListening ? Icons.mic : Icons.mic_off,
                      color: _isListening ? Colors.greenAccent : Colors.grey,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _isListening ? "ESCUCHANDO..." : "MICRO DETENIDO",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _isListening
                            ? Colors.greenAccent
                            : Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              Container(
                width: double.infinity,
                height: 100,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.white24),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _transcripcion.isEmpty ? "Di un color..." : _transcripcion,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontStyle: FontStyle.italic,
                      color: Colors.white,
                    ),
                  ),
                ),
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
        icon: Icon(
          _isListening ? Icons.stop_circle_outlined : Icons.mic_rounded,
          color: Colors.white,
        ),
      ),
    );
  }
}

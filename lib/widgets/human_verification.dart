import 'package:flutter/material.dart';
import '../services/security_service.dart';

class HumanVerificationDialog extends StatefulWidget {
  final bool visual;
  const HumanVerificationDialog({super.key,this.visual=false});
  @override State<HumanVerificationDialog> createState()=>_HumanVerificationDialogState();
}
class _HumanVerificationDialogState extends State<HumanVerificationDialog>{
  late HumanChallenge challenge;
  @override void initState(){super.initState();challenge=widget.visual?HumanVerificationService.generateVisualChallenge():HumanVerificationService.generateChallenge();}
  void choose(String value){if(HumanVerificationService.verify(challenge,value))Navigator.pop(context,true);else ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('إجابة غير صحيحة، حاول مرة أخرى.')));}
  @override Widget build(BuildContext context)=>AlertDialog(title:const Text('تحقق بشري'),content:Column(mainAxisSize:MainAxisSize.min,children:[Text(challenge.question),const SizedBox(height:16),...challenge.options.map((o)=>Padding(padding:const EdgeInsets.only(bottom:8),child:OutlinedButton(onPressed:()=>choose(o),child:Text(o,style:const TextStyle(fontSize:20))))) ]));
}

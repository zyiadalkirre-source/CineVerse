import 'dart:math';
class HumanChallenge {final String question;final List<String> options;final String answer;const HumanChallenge({required this.question,required this.options,required this.answer});}
class HumanVerificationService {
 static final Random _r=Random();
 static HumanChallenge generateChallenge(){final a=_r.nextInt(9)+1,b=_r.nextInt(9)+1,ans=(a+b).toString();final s=<String>{ans};while(s.length<4)s.add((_r.nextInt(17)+2).toString());final o=s.toList()..shuffle();return HumanChallenge(question:'كم يساوي $a + $b ؟',options:o,answer:ans);}
 static HumanChallenge generateImageChallenge()=>generateChallenge();
}
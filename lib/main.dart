import 'dart:convert';
import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const apiUrl=String.fromEnvironment('CARDS_API_URL',defaultValue:'');
const bg=Color(0xFF0A1A2A),surface=Color(0xFF12283D),teal=Color(0xFF1FD1B0),amber=Color(0xFFFFC857),sky=Color(0xFF4DA8FF),muted=Color(0xFF8CA3BA),ink=Color(0xFFEAF2FA);
void main()=>runApp(const AtCardsApp());
class FlashCard{
 String front,back;int interval,reps,due;double ease;
 FlashCard(this.front,this.back,{this.interval=0,this.reps=0,this.due=0,this.ease=2.5});
 bool get mastered=>interval>=7;
 int next(int q){if(q==0)return 0;if(q==1)return math.max(1,(interval*1.2).round());if(q==2){if(reps==0)return 1;if(reps==1)return 3;return math.max(1,(interval*ease).round());}return reps==0?3:math.max(2,(interval*ease*1.3).round());}
 void rate(int q,int day){final n=next(q);if(q==0){reps=0;ease=math.max(1.3,ease-.2);}else{if(q==1)ease=math.max(1.3,ease-.15);if(q==3)ease+=.15;reps++;}interval=n;due=day+n;}
 Map<String,dynamic> toJson()=>{'front':front,'back':back,'interval':interval,'reps':reps,'due':due,'ease':ease};
 factory FlashCard.fromJson(Map<String,dynamic> j)=>FlashCard(j['front']?.toString()??'',j['back']?.toString()??'',interval:(j['interval'] as num?)?.toInt()??0,reps:(j['reps'] as num?)?.toInt()??0,due:(j['due'] as num?)?.toInt()??0,ease:(j['ease'] as num?)?.toDouble()??2.5);
}
class Deck{
 String name;List<FlashCard> cards;Deck(this.name,this.cards);
 Map<String,dynamic> toJson()=>{'name':name,'cards':cards.map((c)=>c.toJson()).toList()};
 factory Deck.fromJson(Map<String,dynamic> j)=>Deck(j['name']?.toString()??'مجموعة',((j['cards'] as List?)??[]).map((e)=>FlashCard.fromJson(Map<String,dynamic>.from(e as Map))).toList());
}
class Store extends ChangeNotifier{
 final List<Deck> decks=[];int today=0,reviewed=0;
 Future<void> load()async{final p=await SharedPreferences.getInstance();today=p.getInt('today')??0;reviewed=p.getInt('reviewed')??0;final raw=p.getString('decks');if(raw!=null){try{decks.addAll((jsonDecode(raw) as List).map((e)=>Deck.fromJson(Map<String,dynamic>.from(e as Map))));}catch(_){}}notifyListeners();}
 Future<void> save()async{final p=await SharedPreferences.getInstance();await p.setInt('today',today);await p.setInt('reviewed',reviewed);await p.setString('decks',jsonEncode(decks.map((d)=>d.toJson()).toList()));}
 int get total=>decks.fold(0,(n,d)=>n+d.cards.length);int get due=>decks.fold(0,(n,d)=>n+d.cards.where((c)=>c.due<=today).length);int get mastered=>decks.fold(0,(n,d)=>n+d.cards.where((c)=>c.mastered).length);
 void add(String name,List<FlashCard> cards){decks.add(Deck(name,cards));save();notifyListeners();}
 void review(FlashCard c,int q){c.rate(q,today);reviewed++;save();notifyListeners();}
 void remove(Deck d){decks.remove(d);save();notifyListeners();}
}
final store=Store();
class AtCardsApp extends StatelessWidget{
 const AtCardsApp({super.key});
 @override Widget build(BuildContext context)=>MaterialApp(debugShowCheckedModeBanner:false,title:'بطاقات AT',locale:const Locale('ar'),supportedLocales:const [Locale('ar'),Locale('en')],localizationsDelegates:GlobalMaterialLocalizations.delegates,theme:ThemeData(useMaterial3:true,brightness:Brightness.dark,scaffoldBackgroundColor:bg,colorScheme:const ColorScheme.dark(primary:teal,secondary:amber,surface:surface),appBarTheme:const AppBarTheme(backgroundColor:bg,foregroundColor:ink)),home:const HomePage());
}
class HomePage extends StatefulWidget{const HomePage({super.key});@override State<HomePage> createState()=>_HomePageState();}
class _HomePageState extends State<HomePage>{
 int tab=0;bool loading=false;
 @override void initState(){super.initState();store.load();}
 Future<void> importPdf()async{
  final pick=await FilePicker.platform.pickFiles(type:FileType.custom,allowedExtensions:['pdf'],withData:true);if(pick==null||!mounted)return;
  if(apiUrl.isEmpty){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('رفع PDF يحتاج إعداد رابط محرك الذكاء الاصطناعي. يمكنك إنشاء البطاقات يدويًا الآن.')));return;}
  setState(()=>loading=true);
  try{final f=pick.files.single;final req=http.MultipartRequest('POST',Uri.parse(apiUrl));req.files.add(http.MultipartFile.fromBytes('file',f.bytes!,filename:f.name));final stream=await req.send().timeout(const Duration(seconds:90));final res=await http.Response.fromStream(stream);if(res.statusCode<200||res.statusCode>=300)throw Exception('HTTP '+res.statusCode.toString());final data=jsonDecode(res.body) as Map<String,dynamic>;final cards=(data['cards'] as List).map((e)=>FlashCard(e['front'].toString(),e['back'].toString())).toList();if(cards.isEmpty)throw Exception('لا توجد بطاقات');store.add(f.name.replaceAll(RegExp(r'\.pdf$',caseSensitive:false),''),cards);if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تم استيراد '+cards.length.toString()+' بطاقة')));}
  catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تعذر التحويل: '+e.toString())));}finally{if(mounted)setState(()=>loading=false);}
 }
 Future<void> addCard()async{
  final name=TextEditingController(),front=TextEditingController(),back=TextEditingController();
  final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(backgroundColor:surface,title:const Text('إنشاء بطاقة'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:name,decoration:const InputDecoration(labelText:'اسم المجموعة')),TextField(controller:front,decoration:const InputDecoration(labelText:'السؤال')),TextField(controller:back,decoration:const InputDecoration(labelText:'الجواب'),maxLines:3)])),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('إضافة'))]));
  if(ok==true&&name.text.trim().isNotEmpty&&front.text.trim().isNotEmpty&&back.text.trim().isNotEmpty)store.add(name.text.trim(),[FlashCard(front.text.trim(),back.text.trim())]);name.dispose();front.dispose();back.dispose();
 }
 @override Widget build(BuildContext context)=>AnimatedBuilder(animation:store,builder:(context,_)=>Scaffold(appBar:AppBar(title:const Text('بطاقات AT',style:TextStyle(fontWeight:FontWeight.w800))),floatingActionButton:tab==0?FloatingActionButton.extended(onPressed:loading?null:importPdf,icon:loading?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.upload_file),label:Text(loading?'جارٍ التحويل':'رفع PDF')):null,bottomNavigationBar:NavigationBar(backgroundColor:surface,selectedIndex:tab,onDestinationSelected:(i)=>setState(()=>tab=i),destinations:const [NavigationDestination(icon:Icon(Icons.style_outlined),label:'مجموعاتي'),NavigationDestination(icon:Icon(Icons.bar_chart_outlined),label:'الإحصائيات')]),body:SafeArea(child:tab==0?homeBody():statsBody())));
 Widget homeBody()=>ListView(padding:const EdgeInsets.fromLTRB(18,12,18,100),children:[const Text('أهلًا يا دكتور 👋',style:TextStyle(fontSize:25,fontWeight:FontWeight.w800,color:ink)),const SizedBox(height:18),Container(padding:const EdgeInsets.all(20),decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xFF164F69),Color(0xFF147E75)]),borderRadius:BorderRadius.circular(24)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('مراجعة اليوم'),const SizedBox(height:6),Text(store.due.toString()+' بطاقة بانتظارك',style:const TextStyle(fontSize:23,fontWeight:FontWeight.bold)),Text('الإجمالي: '+store.total.toString()+' • المتقنة: '+store.mastered.toString()),const SizedBox(height:12),FilledButton.tonal(onPressed:store.due==0?null:startDue,child:const Text('ابدأ المراجعة'))])),const SizedBox(height:22),Row(children:[const Expanded(child:Text('مجموعاتك',style:TextStyle(fontSize:19,fontWeight:FontWeight.bold))),IconButton(onPressed:addCard,icon:const Icon(Icons.add_circle,color:teal))]),if(store.decks.isEmpty)const Padding(padding:EdgeInsets.all(24),child:Column(children:[Icon(Icons.auto_stories,size:48,color:teal),Text('أنشئ بطاقة يدويًا أو ارفع PDF بعد إعداد محرك التحويل.',textAlign:TextAlign.center)])),for(final d in store.decks)Card(color:surface,child:ListTile(leading:const Icon(Icons.style,color:teal),title:Text(d.name),subtitle:Text(d.cards.length.toString()+' بطاقة • '+d.cards.where((c)=>c.due<=store.today).length.toString()+' مستحقة'),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>StudyPage(deck:d))),trailing:IconButton(icon:const Icon(Icons.delete_outline,color:Colors.redAccent),onPressed:()=>store.remove(d))))]);
 void startDue(){final d=store.decks.firstWhere((d)=>d.cards.any((c)=>c.due<=store.today));Navigator.push(context,MaterialPageRoute(builder:(_)=>StudyPage(deck:d)));}
 Widget statsBody()=>ListView(padding:const EdgeInsets.all(20),children:[const Text('إحصائياتك',style:TextStyle(fontSize:25,fontWeight:FontWeight.bold)),const SizedBox(height:20),stat('إجمالي البطاقات',store.total),stat('المستحق اليوم',store.due),stat('البطاقات المتقنة',store.mastered),stat('المراجعات المنجزة',store.reviewed)]);
 Widget stat(String s,int n)=>Card(color:surface,child:ListTile(title:Text(s),trailing:Text(n.toString(),style:const TextStyle(color:teal,fontSize:22,fontWeight:FontWeight.bold))));
}
class StudyPage extends StatefulWidget{final Deck deck;const StudyPage({super.key,required this.deck});@override State<StudyPage> createState()=>_StudyPageState();}
class _StudyPageState extends State<StudyPage>{
 bool flipped=false;int completed=0;
 @override Widget build(BuildContext context){final cards=widget.deck.cards.where((c)=>c.due<=store.today).toList();return Scaffold(appBar:AppBar(title:Text(widget.deck.name)),body:SafeArea(child:cards.isEmpty?Center(child:Column(mainAxisSize:MainAxisSize.min,children:[const Icon(Icons.celebration,color:teal,size:64),const Text('أحسنت! لا توجد بطاقات مستحقة'),FilledButton(onPressed:()=>Navigator.pop(context),child:const Text('العودة'))]):Padding(padding:const EdgeInsets.all(20),child:Column(children:[Text('تمت مراجعة '+completed.toString()+' بطاقة'),const SizedBox(height:18),Expanded(child:GestureDetector(onTap:()=>setState(()=>flipped=!flipped),child:Container(width:double.infinity,padding:const EdgeInsets.all(24),decoration:BoxDecoration(color:surface,borderRadius:BorderRadius.circular(28),border:Border.all(color:teal.withOpacity(.4))),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[Icon(flipped?Icons.lightbulb_outline:Icons.help_outline,color:teal,size:42),const SizedBox(height:18),Text(flipped?'الجواب':'السؤال',style:const TextStyle(color:muted)),const SizedBox(height:14),Text(flipped?cards.first.back:cards.first.front,textAlign:TextAlign.center,style:const TextStyle(fontSize:24,fontWeight:FontWeight.bold,color:ink)),const SizedBox(height:20),const Text('اضغط لقلب البطاقة',style:TextStyle(color:muted))])))),const SizedBox(height:18),if(flipped)Row(children:[rateButton('نسيت',Colors.redAccent,0,cards.first),rateButton('صعب',amber,1,cards.first),rateButton('جيد',sky,2,cards.first),rateButton('سهل',teal,3,cards.first)])else const SizedBox(height:55)]))));}
 Widget rateButton(String label,Color color,int q,FlashCard c)=>Expanded(child:Padding(padding:const EdgeInsets.symmetric(horizontal:3),child:FilledButton(style:FilledButton.styleFrom(backgroundColor:color,foregroundColor:bg),onPressed:(){store.review(c,q);setState((){flipped=false;completed++;});},child:Text(label))));
}

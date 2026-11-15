import 'dart:convert';
import 'package:flutter/material.dart';
class PracticePage extends StatefulWidget {
  final List<Map<String,dynamic>> questions;
  final String lessonTitle;
  const PracticePage({super.key, required this.questions, required this.lessonTitle});
  @override
  State<PracticePage> createState() => _PracticePageState();
}
class _PracticePageState extends State<PracticePage> {
  int index=0, correct=0;
  String? selected;
  bool submitted=false;
  @override
  Widget build(BuildContext context) {
    if (index >= widget.questions.length) {
      return Scaffold(appBar: AppBar(title: const Text('Hoàn thành')),
        body: Center(child: Column(mainAxisSize: MainAxisSize.min, children:[
          const Icon(Icons.emoji_events, size:64, color: Colors.orange),
          Text('Đúng $correct / ${widget.questions.length}',style:Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height:12),
          const Text('Điểm hiện tại trên thiết bị • chưa đồng bộ'),
          FilledButton(onPressed: ()=>Navigator.pop(context),
            child: const Text('Về bài học')),
        ])));
    }
    final q=widget.questions[index];
    final kind=q['questionType']?.toString();
    List<String> options=[];
    if(kind=='single_choice'||kind=='multi_choice') {
      try {options=(jsonDecode(q['optionsJson']?.toString()??'[]') as List)
        .map((v)=>v.toString()).toList();} catch(_){options=[];}
    } else if (kind=='true_false') { options=['Đúng','Sai']; }
    return Scaffold(appBar: AppBar(title: Text(widget.lessonTitle)),
      body: ListView(padding: const EdgeInsets.all(16),children:[
        LinearProgressIndicator(value:(index+1)/widget.questions.length),
        const SizedBox(height:18),
        Text('Câu ${index+1} / ${widget.questions.length}',style:Theme.of(context).textTheme.titleMedium),
        const SizedBox(height:10),
        Card(child:Padding(padding:const EdgeInsets.all(18),
          child:Text(q['questionText']?.toString()??'',style:Theme.of(context).textTheme.titleLarge))),
        if(options.isNotEmpty)
          ...options.map((option)=>Card(child:RadioListTile<String>(
            title:Text(option),value:option,groupValue:selected,
            onChanged:submitted?null:(value)=>setState(()=>selected=value),
          )))
        else TextField(
          key:ValueKey('answer-$index'), enabled:!submitted,
          decoration:const InputDecoration(labelText:'Nhập câu trả lời',border:OutlineInputBorder()),
          onChanged:(value)=>selected=value),
        if(submitted) Card(child:Padding(padding:const EdgeInsets.all(14),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(selected?.trim()==q['correctAnswer']?.toString().trim()?
              'Chính xác!':'Chưa đúng. Đáp án: ${q['correctAnswer']}',
              style:Theme.of(context).textTheme.titleMedium),
            if(q['explanationSimple']!=null)Text(q['explanationSimple'].toString()),
          ]))),
        const SizedBox(height:16),
        FilledButton(
          onPressed: submitted ? ()=>setState(() {index++;selected=null;submitted=false;}) :
            ()=>setState(() {if(selected==null||selected!.trim().isEmpty)return;
              if(selected!.trim()==q['correctAnswer']?.toString().trim())correct++;
              submitted=true;
            }),
          child:Text(submitted?'Câu tiếp theo':'Kiểm tra'),
        ),
      ]));
  }
}

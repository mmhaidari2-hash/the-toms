import 'package:british_life/core/engine/conversation_engine.dart';
import 'package:british_life/core/models/dialogue_node.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const generic = Branch(
    keywords: ['yes', 'could', 'you', 'please'],
    suggestion: 'Yes, please.',
    suggestionFa: '',
    trustDelta: 1,
    next: 'generic',
  );
  const question = Branch(
    keywords: ['dbs'],
    suggestion: 'Yes. Could you explain what DBS covers?',
    suggestionFa: '',
    trustDelta: 1,
    next: 'dbs',
  );
  const node = DialogueNode(
    id: 'test',
    speaker: 'narrator',
    text: '',
    translations: {},
    branches: [generic, question],
    newWords: [],
  );
  test('an exact authored reply wins over overlapping generic keywords', () {
    final result = ConversationEngine.match(
      node,
      'YES! Could you explain what DBS covers?',
      vocab: ['DBS'],
    );
    expect(result.branch, same(question));
    expect(result.matchedWords, ['DBS']);
  });
  test('free answers still use whole-word keyword matching', () {
    expect(
      ConversationEngine.match(node, 'Explain DBS').branch,
      same(question),
    );
    expect(ConversationEngine.match(node, 'yesterday banana').matched, isFalse);
  });
}

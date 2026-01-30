import 'package:flutter/material.dart';
import 'package:instagram_clone_flutter/utils/colors.dart';

// Built-in sticker packs using emoji combinations as stickers
// This avoids needing external asset files while providing LINE-like sticker experience
class StickerPack {
  final String id;
  final String name;
  final String icon;
  final List<String> stickers;

  const StickerPack({
    required this.id,
    required this.name,
    required this.icon,
    required this.stickers,
  });
}

// Default sticker packs - emoji-based stickers (LINE-style)
const List<StickerPack> defaultStickerPacks = [
  StickerPack(
    id: 'emotions',
    name: 'Emotions',
    icon: '\u{1F60A}',
    stickers: [
      '\u{1F60A}', '\u{1F602}', '\u{1F60D}', '\u{1F618}', '\u{1F609}',
      '\u{1F914}', '\u{1F631}', '\u{1F622}', '\u{1F621}', '\u{1F60E}',
      '\u{1F634}', '\u{1F637}', '\u{1F4A2}', '\u{1F44D}', '\u{1F44F}',
      '\u{1F64F}', '\u{1F44B}', '\u{270C}\u{FE0F}', '\u{1F4AA}', '\u{1F44A}',
      '\u{1F48B}', '\u{2764}\u{FE0F}', '\u{1F494}', '\u{1F495}',
    ],
  ),
  StickerPack(
    id: 'animals',
    name: 'Animals',
    icon: '\u{1F436}',
    stickers: [
      '\u{1F436}', '\u{1F431}', '\u{1F42D}', '\u{1F430}', '\u{1F43B}',
      '\u{1F437}', '\u{1F438}', '\u{1F435}', '\u{1F427}', '\u{1F98A}',
      '\u{1F981}', '\u{1F406}', '\u{1F434}', '\u{1F984}', '\u{1F41D}',
      '\u{1F98B}', '\u{1F422}', '\u{1F419}', '\u{1F42C}', '\u{1F433}',
    ],
  ),
  StickerPack(
    id: 'food',
    name: 'Food',
    icon: '\u{1F354}',
    stickers: [
      '\u{1F354}', '\u{1F355}', '\u{1F363}', '\u{1F371}', '\u{1F370}',
      '\u{1F366}', '\u{1F369}', '\u{1F382}', '\u{2615}', '\u{1F37A}',
      '\u{1F377}', '\u{1F37B}', '\u{1F34E}', '\u{1F34C}', '\u{1F353}',
      '\u{1F347}', '\u{1F349}', '\u{1F951}', '\u{1F35C}', '\u{1F372}',
    ],
  ),
  StickerPack(
    id: 'activities',
    name: 'Activities',
    icon: '\u{26BD}',
    stickers: [
      '\u{26BD}', '\u{1F3C0}', '\u{1F3C8}', '\u{26BE}', '\u{1F3BE}',
      '\u{1F3B5}', '\u{1F3B6}', '\u{1F3A4}', '\u{1F3AC}', '\u{1F3AE}',
      '\u{1F3A8}', '\u{1F3AD}', '\u{1F3C6}', '\u{1F3C4}', '\u{1F6B4}',
      '\u{1F3CB}\u{FE0F}', '\u{1F3CA}', '\u{26F7}\u{FE0F}', '\u{1F3AF}', '\u{1F3B1}',
    ],
  ),
  StickerPack(
    id: 'family',
    name: 'Family',
    icon: '\u{1F46A}',
    stickers: [
      '\u{1F46A}', '\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467}',
      '\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F466}\u{200D}\u{1F466}',
      '\u{1F46B}', '\u{1F46D}', '\u{1F46C}',
      '\u{1F476}', '\u{1F474}', '\u{1F475}', '\u{1F468}', '\u{1F469}',
      '\u{1F466}', '\u{1F467}', '\u{1F3E0}', '\u{1F3E1}',
      '\u{1F496}', '\u{1F49E}', '\u{1F49D}', '\u{1F381}', '\u{1F389}',
    ],
  ),
  StickerPack(
    id: 'weather',
    name: 'Weather',
    icon: '\u{2600}\u{FE0F}',
    stickers: [
      '\u{2600}\u{FE0F}', '\u{1F324}\u{FE0F}', '\u{26C5}', '\u{1F325}\u{FE0F}',
      '\u{2601}\u{FE0F}', '\u{1F326}\u{FE0F}', '\u{1F327}\u{FE0F}', '\u{26C8}\u{FE0F}',
      '\u{1F329}\u{FE0F}', '\u{1F328}\u{FE0F}', '\u{2744}\u{FE0F}', '\u{1F32C}\u{FE0F}',
      '\u{1F32B}\u{FE0F}', '\u{1F308}', '\u{1F319}', '\u{1F31E}',
      '\u{2B50}', '\u{1F31F}', '\u{1F30A}', '\u{1F525}',
    ],
  ),
];

class StickerPickerWidget extends StatefulWidget {
  final Function(String sticker, String packId) onStickerSelected;

  const StickerPickerWidget({
    Key? key,
    required this.onStickerSelected,
  }) : super(key: key);

  @override
  State<StickerPickerWidget> createState() => _StickerPickerWidgetState();
}

class _StickerPickerWidgetState extends State<StickerPickerWidget> {
  int _selectedPackIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      color: mobileBackgroundColor,
      child: Column(
        children: [
          // Pack selector tabs
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.grey[900],
              border: Border(
                top: BorderSide(color: Colors.grey[800]!, width: 0.5),
              ),
            ),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: defaultStickerPacks.length,
              itemBuilder: (context, index) {
                bool isSelected = index == _selectedPackIndex;
                return GestureDetector(
                  onTap: () => setState(() => _selectedPackIndex = index),
                  child: Container(
                    width: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color:
                              isSelected ? lineGreenColor : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Text(
                      defaultStickerPacks[index].icon,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                );
              },
            ),
          ),
          // Sticker grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount:
                  defaultStickerPacks[_selectedPackIndex].stickers.length,
              itemBuilder: (context, index) {
                String sticker =
                    defaultStickerPacks[_selectedPackIndex].stickers[index];
                String packId =
                    defaultStickerPacks[_selectedPackIndex].id;

                return GestureDetector(
                  onTap: () => widget.onStickerSelected(sticker, packId),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey[900],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      sticker,
                      style: const TextStyle(fontSize: 36),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

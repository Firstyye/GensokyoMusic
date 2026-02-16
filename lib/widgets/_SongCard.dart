import 'package:flutter/material.dart';
// import '../constant/my_constant.dart'; // <--- อย่าลืม import file constant ของคุณถ้าต้องการใช้ bodyTextStyle

class SongCard extends StatelessWidget {
  final String title;
  final String viewerCount;
  final String? backgroundImage; // ไม่ require (Optional)

  const SongCard({
    super.key,
    required this.title,
    required this.viewerCount,
    this.backgroundImage,
  });

  @override
  Widget build(BuildContext context) {
    ImageProvider imageProvider;
    if( backgroundImage != null && backgroundImage!.startsWith('http')) {
      imageProvider = NetworkImage(backgroundImage!);
    } else {
      imageProvider = AssetImage(backgroundImage ?? 'lib/pages/images/SongBanner/COOL&CREATE.jpg');
    }
    return Container(
      margin: const EdgeInsets.only(right: 15.0),
      width: 150,
      height: 150,
      decoration: BoxDecoration(
        image: DecorationImage(
          // ถ้าไม่มีการส่งรูปมา จะใช้รูป Default นี้แทน
          image: imageProvider,
          fit: BoxFit.cover,
        ),
        color: Colors.grey.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          // 1. Gradient Shadow (เงาดำด้านล่าง)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 80,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.8),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // 2. Viewer Count Badge (มุมขวาบน)
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.people,
                    size: 12,
                    color: Colors.blueAccent,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    viewerCount, // <--- ใช้ตัวแปรที่รับมา
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Title & On Air Status (มุมซ้ายล่าง)
          Positioned(
            bottom: 10,
            left: 10,
            right: 10,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.bar_chart,
                      color: Colors.cyanAccent, // ปรับสีให้เด่นขึ้นนิดหน่อยบนพื้นดำ
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'ON AIR',
                      style: TextStyle(
                        color: Colors.cyanAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      // หมายเหตุ: ถ้าคุณ import constant แล้ว ให้ใช้บรรทัดล่างนี้แทน
                      // style: bodyTextStyle.copyWith(color: Colors.cyanAccent, fontSize: 10),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  title, // <--- ใช้ตัวแปรที่รับมา
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis, // ตัดคำถ้าชื่อยาวเกิน
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12, // ปรับขนาดให้อ่านง่ายขึ้น
                    fontWeight: FontWeight.bold,
                  ),
                  // หมายเหตุ: ถ้าคุณ import constant แล้ว ให้ใช้บรรทัดล่างนี้แทน
                  // style: bodyTextStyle.copyWith(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
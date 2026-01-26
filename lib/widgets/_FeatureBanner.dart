import 'package:flutter/material.dart';
import '../constant/my_constant.dart';

class FeatureBanner extends StatelessWidget {
  final String circlename;
  final String titlename;
  final String? buttonname;
  final String? backgroundimage;
  const FeatureBanner({
    super.key,
    required this.circlename,
    required this.titlename,
    this.backgroundimage,
    this.buttonname,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 20.0, bottom: 20),
      child: Container(
        width: double.infinity,
        height: 150,
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              spreadRadius: 5,
              blurRadius: 7,
            ),
          ],
          image: DecorationImage(
            image: AssetImage(
              backgroundimage ?? 'lib/pages/images/SongBanner/COOL&CREATE.jpg',
            ),
            fit: BoxFit.cover,
          ),

          color: Colors.grey.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          children: [
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
                    colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10,
              left: 10,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
                  backgroundColor: Colors.white.withOpacity(0.8),
                  elevation: 0,
                ),
                onPressed: () {},
                child: Text(
                  buttonname ?? "NEW ALBUM",
                  style: bodyTextStyle.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 10,
              left: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Text(
                    titlename,
                    // "Chou Saikyou! Saishuu Kichiku Imouto Flandre S",
                    style: bodyTextStyle.copyWith(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    circlename,
                    // 'COOL&CREATE',
                    style: headerTextStyle.copyWith(color: Colors.white),
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 10,
              right: 10,
              child: IconButton(
                onPressed: () {},
                icon: Icon(
                  Icons.play_circle_fill,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

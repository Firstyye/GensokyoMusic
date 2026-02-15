import 'package:flutter/material.dart';
import 'package:yo/constant/my_constant.dart';
class SongMenu extends StatelessWidget {
  final String? title;
  final String? artist;
  final String? image;
  final String? number;
  const SongMenu({
    super.key,
    required this.title,
    required this.artist,
    this.image,
    this.number,
  
  
  });

  @override
  Widget build(BuildContext context) {
    ImageProvider imageProvider;
    if( image != null && image!.startsWith('http')) {
      imageProvider = NetworkImage(image!);
    } else {
      imageProvider = AssetImage(image ?? 'lib/pages/images/SongBanner/COOL&CREATE.jpg');
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            width: double.infinity,
            height: 80, 
            child: Row(
             
              children: [
                
                SizedBox(width: 16),
                SizedBox(
                  width: 10,
                  child: Text(
                    number ?? "1",
                    style: bodyTextStyle.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                
                SizedBox(width: 16),
                
               
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    image: DecorationImage(
                      image: imageProvider,
                      fit: BoxFit.fill,
                    ),
                  ),
                ),

                SizedBox(width: 16), 

               
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title ?? "Help me, ERINNNNNN!!",
                       
                        maxLines: 1, 
                        overflow: TextOverflow.ellipsis, 
                        style: bodyTextStyle.copyWith(
                          fontWeight: FontWeight.bold,
                          height: 1.2, 
                        ),
                      ),
                      Text(
                         artist ?? "BeatMARIO",
                         maxLines: 1,
                         overflow: TextOverflow.ellipsis,
                         style: bodyTextStyle.copyWith(
                           fontSize: 12,
                         ), 
                      ),
                    ],
                  ),
                ),

                // 4. Icon
                Icon(Icons.more_horiz),
                SizedBox(width: 16), 
              ],
            ),
          ),
        ],
      ),
    );
  }
}
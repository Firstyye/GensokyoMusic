import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../data/product.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ProductScreen extends StatefulWidget {
  const ProductScreen({super.key});

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  final List<Product> products = [
    Product(
      name: "IPHONE18",
      price: 999.99,
      image:
          "https://www.macworld.com/wp-content/uploads/2026/01/iPhone-17-Pro-Max-camera-system-3.jpg?quality=50&strip=all",
      inStock: true,
    ),
    Product(
      name: "Samsung S26",
      price: 999.99,
      image:
          "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQqhtia1I3QQGnMDnNea8uFF00flX1tJPHxKQ&s",
      inStock: true,
    ),
    Product(
      name: "Xiaomi Mi 14",
      price: 999.99,
      image:
          "https://i02.appmifile.com/529_operator_sg/18/01/2024/ba1d009234a56edd7aec73a7a80a2258.png",
      inStock: true,
    ),
    Product(
      name: "Oppo Find X6",
      price: 999.99,
      image:
          "https://www.oppo.com/content/dam/oppo/product-asset-library/reno/reno14-series/en/reno14-f/blue-green-pink/v1/assets/images-ksp-phone-mo-s3.png",
      inStock: true,
    ),
  ];

  List api_products = [];
  bool isLoading = true;
  Future<void> fetchProducts() async {
    final response = await http.get(Uri.parse("https://touhoudb.com/api/albums/4472?fields=MainPicture"));
    if (response.statusCode == 200) {
      setState(() {
        var data = json.decode(response.body);
        api_products = [  
          {
            "name": data['defaultName'],
           
            "mainPicture": data['mainPicture']['urlOriginal'], 
        
            "price": 9.99,
            "inStock": true
          }
        ];
        isLoading = false;
        print(api_products);
        String img = (api_products[0]['mainPicture']);
        String resultImg = img.substring(0,img.indexOf("?"));
        api_products[0]['mainPicture'] = resultImg;
        print(api_products[0]['mainPicture']);
      });
    } else {
      print("Failed to load products");
    }
  }

  @override
  void initState() {
    super.initState();
    fetchProducts();
  }
  
  String proxyUrl = "https://corsproxy.io/url=";

  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Products")),
      body: ListView.builder(
        
        itemCount: api_products.length,
        itemBuilder: (context, index) {
          final product = api_products[index];
          return ListTile(
            onTap: () {
              print("Product's Name : ${product['name']}");
              print("Product's ID : $index");
            },
            
            leading: CachedNetworkImage(
              imageUrl: "${product['mainPicture']}",
              width: 80,
              height: 80,
              memCacheWidth: 160, // 80 * 2
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                width: 80,
                height: 80,
                color: Colors.white.withValues(alpha: 0.05),
              ),
              errorWidget: (context, url, error) => const Icon(Icons.error),
            ),
            title: Text(product['name']),
            subtitle: Text("\$${product['price'].toStringAsFixed(2)}"),
            trailing: product['inStock']
                ? const Text("In Stock", style: TextStyle(color: Colors.green))
                : const Text(
                    "Out of Stock",
                    style: TextStyle(color: Colors.red),
                  ),
          );
        },
      ),
    );
  }
}

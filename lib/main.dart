import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// --- GLOBAL STATE (Memory for our app) ---
List<Product> globalProducts = []; // NEW: Saves products so we don't re-download when switching tabs
List<String> globalCategories = ["All"];
List<Product> globalCart = [];
List<Product> globalFavorites = [];

void main() {
  runApp(const SoraSiApp());
}

class SoraSiApp extends StatelessWidget {
  const SoraSiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SoraSi Store',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF800020)), // Burgundy theme
        scaffoldBackgroundColor: Colors.grey[100], 
      ),
      // CHANGED: The app now starts on the MainScreen (the tab bar wrapper)
      home: const MainScreen(),
    );
  }
}

// --- 0. THE MAIN TAB CONTROLLER (Brand New) ---
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // Tracks which tab is currently selected (0 = Home, 1 = Favorites, 2 = Cart)
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The body changes based on the selected tab
      body: _currentIndex == 0
          ? const HomeScreen()
          : _currentIndex == 1
              ? const FavoritesScreen()
              : const CartScreen(),
              
      // NEW: The Bottom Navigation Bar
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: const Color(0xFF800020), // Burgundy for active tab
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() {
            _currentIndex = index; // Switch the screen when a tab is tapped
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: "Favorites"),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: "Cart"),
        ],
      ),
    );
  }
}

// --- 1. THE DATA MODEL ---
class Product {
  final int id;
  final String title;
  final double price;
  final String description;
  final String category;
  final String image;

  Product({
    required this.id,
    required this.title,
    required this.price,
    required this.description,
    required this.category,
    required this.image,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'],
      title: json['title'],
      price: json['price'].toDouble(),
      description: json['description'],
      category: json['category'],
      image: json['thumbnail'], 
    );
  }
}

// --- 2. THE HOME SCREEN ---
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Product> allProducts = [];
  List<Product> displayedProducts = [];
  
  bool isLoading = true;
  String errorMessage = "";

  String searchQuery = "";
  String selectedCategory = "All";
  List<String> categories = ["All"];

  @override
  void initState() {
    super.initState();
    // CHANGED: Only fetch from internet if our global memory is empty
    if (globalProducts.isEmpty) {
      fetchProducts();
    } else {
      // If we already downloaded them, just load them from memory instantly
      allProducts = globalProducts;
      displayedProducts = globalProducts;
      categories = globalCategories;
      isLoading = false;
    }
  }

  Future<void> fetchProducts() async {
    final url = Uri.parse('https://dummyjson.com/products');
    
    try {
      final response = await http.get(url, headers: {
        "User-Agent": "Mozilla/5.0", 
        "Accept": "application/json",
      });

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        List<dynamic> data = responseData['products']; 

        List<Product> fetchedProducts = data.map((json) => Product.fromJson(json)).toList();
        
        fetchedProducts.removeWhere((product) => 
            product.category == 'smartphones' || product.category == 'laptops');

        Set<String> uniqueCategories = {"All"};
        for (var product in fetchedProducts) {
          uniqueCategories.add(product.category);
        }

        setState(() {
          allProducts = fetchedProducts;
          displayedProducts = fetchedProducts;
          categories = uniqueCategories.toList();
          isLoading = false;
          
          // Save to global memory for next time
          globalProducts = fetchedProducts;
          globalCategories = categories;
        });
      } else {
        throw Exception('Server failed with status code: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = e.toString();
      });
    }
  }

  void applyFilters() {
    setState(() {
      displayedProducts = allProducts.where((product) {
        final titleMatches = product.title.toLowerCase().contains(searchQuery.toLowerCase());
        final categoryMatches = selectedCategory == "All" || product.category == selectedCategory;
        
        return titleMatches && categoryMatches;
      }).toList();
    });
  }

  bool isFavorite(Product product) {
    return globalFavorites.any((item) => item.id == product.id);
  }

  void toggleFavorite(Product product) {
    setState(() {
      if (isFavorite(product)) {
        globalFavorites.removeWhere((item) => item.id == product.id);
      } else {
        globalFavorites.add(product);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("SoraSi", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF800020), 
        elevation: 1,
        // (Cart icon removed from here, it is now in the bottom tabs)
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage.isNotEmpty
              ? Center(child: Text(errorMessage, style: const TextStyle(color: Colors.red)))
              : Column(
                  children: [
                    // --- SEARCH & FILTER SECTION ---
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              onChanged: (value) {
                                searchQuery = value;
                                applyFilters();
                              },
                              decoration: InputDecoration(
                                hintText: "Search products...",
                                prefixIcon: const Icon(Icons.search),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedCategory,
                                items: categories.map((String category) {
                                  return DropdownMenuItem<String>(
                                    value: category,
                                    child: Text(
                                      category.length > 12 ? '${category.substring(0, 12)}...' : category,
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (newValue) {
                                  if (newValue != null) {
                                    selectedCategory = newValue;
                                    applyFilters();
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // --- PRODUCT LIST SECTION ---
                    Expanded(
                      child: ListView.builder(
                        itemCount: displayedProducts.length,
                        itemBuilder: (context, index) {
                          final product = displayedProducts[index];
                          return GestureDetector(
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => DetailsScreen(product: product),
                                ),
                              );
                              setState(() {}); // Refresh hearts when returning
                            },
                            child: Card(
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 2,
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Image.network(product.image, width: 80, height: 80, fit: BoxFit.contain),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            product.title,
                                            maxLines: 2, 
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            "${product.price.toStringAsFixed(2)} SAR",
                                            style: const TextStyle(color: Color(0xFF800020), fontWeight: FontWeight.bold, fontSize: 18),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        isFavorite(product) ? Icons.favorite : Icons.favorite_border,
                                        color: isFavorite(product) ? const Color(0xFF800020) : Colors.grey,
                                      ),
                                      onPressed: () => toggleFavorite(product),
                                    ),
                                  ],
                                ),
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

// --- 3. THE FAVORITES SCREEN (Brand New) ---
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  void removeFromFavorites(Product product) {
    setState(() {
      globalFavorites.removeWhere((item) => item.id == product.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Favorites"),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF800020),
      ),
      body: globalFavorites.isEmpty
          ? const Center(
              child: Text("You haven't liked any items yet!", style: TextStyle(fontSize: 18, color: Colors.grey)),
            )
          : ListView.builder(
              itemCount: globalFavorites.length,
              itemBuilder: (context, index) {
                final product = globalFavorites[index];
                return ListTile(
                  leading: Image.network(product.image, width: 50, height: 50),
                  title: Text(product.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text("${product.price.toStringAsFixed(2)} SAR"),
                  // Button to remove from favorites
                  trailing: IconButton(
                    icon: const Icon(Icons.favorite, color: Color(0xFF800020)),
                    onPressed: () => removeFromFavorites(product),
                  ),
                );
              },
            ),
    );
  }
}

// --- 4. THE CART SCREEN ---
class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  double getTotalPrice() {
    double total = 0;
    for (var item in globalCart) {
      total += item.price;
    }
    return total;
  }

  void removeFromCart(Product product) {
    setState(() {
      globalCart.remove(product);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Shopping Cart"),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF800020),
      ),
      body: globalCart.isEmpty
          ? const Center(
              child: Text("Your cart is empty!", style: TextStyle(fontSize: 18, color: Colors.grey)),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: globalCart.length,
                    itemBuilder: (context, index) {
                      final product = globalCart[index];
                      return ListTile(
                        leading: Image.network(product.image, width: 50, height: 50),
                        title: Text(product.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text("${product.price.toStringAsFixed(2)} SAR"),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => removeFromCart(product),
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(20),
                  color: Colors.white,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Total:", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      Text(
                        "${getTotalPrice().toStringAsFixed(2)} SAR",
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF800020)),
                      ),
                    ],
                  ),
                )
              ],
            ),
    );
  }
}

// --- 5. THE DETAILS SCREEN ---
class DetailsScreen extends StatefulWidget {
  final Product product;

  const DetailsScreen({super.key, required this.product});

  @override
  State<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends State<DetailsScreen> {
  
  bool isFavorite() {
    return globalFavorites.any((item) => item.id == widget.product.id);
  }

  void toggleFavorite() {
    setState(() {
      if (isFavorite()) {
        globalFavorites.removeWhere((item) => item.id == widget.product.id);
      } else {
        globalFavorites.add(widget.product);
      }
    });
  }

  void addToCart() {
    globalCart.add(widget.product);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("${widget.product.title} added to cart!"),
        backgroundColor: const Color(0xFF800020),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Product Details"),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF800020), 
        actions: [
          IconButton(
            icon: Icon(
              isFavorite() ? Icons.favorite : Icons.favorite_border,
            ),
            onPressed: toggleFavorite,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Image.network(
                      widget.product.image,
                      height: 300,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 30),
                  Text(
                    widget.product.title,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "${widget.product.price.toStringAsFixed(2)} SAR",
                    style: const TextStyle(fontSize: 26, color: Color(0xFF800020), fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "Description",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.grey),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.product.description,
                    style: const TextStyle(fontSize: 16, height: 1.6, color: Colors.black87),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.grey.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, -3)),
              ]
            ),
            child: ElevatedButton(
              onPressed: addToCart,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF800020),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text(
                "Add to Cart", 
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
              ),
            ),
          ),
        ],
      ),
    );
  }
}
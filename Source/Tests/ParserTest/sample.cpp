// Sample input for parsertest: a bit of everything the class browser shows.
#include <iostream>
#include <string>
#include <vector>

#define GREETING "hello"

namespace shapes {

enum Color { Red, Green, Blue };

class Shape {
public:
    virtual ~Shape() {}
    virtual double Area() const = 0;
protected:
    Color fColor;
};

class Circle : public Shape {
public:
    explicit Circle(double radius);
    double Area() const override;
private:
    double fRadius;
};

}

typedef std::vector<std::string> NameList;

int globalCounter = 0;

static void PrintNames(const NameList& names)
{
    for (const std::string& name : names)
        std::cout << name << '\n';
}

int main()
{
    NameList names = {"a", "b"};
    PrintNames(names);
    std::cout << GREETING << std::endl;
    return 0;
}

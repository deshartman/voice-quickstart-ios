import UIKit

class EmailInputViewController: UIViewController {
    
    @IBOutlet weak var emailTextField: UITextField!
    var completion: ((String) -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    @IBAction func submitButtonTapped(_ sender: UIButton) {
        guard let email = emailTextField.text, !email.isEmpty else {
            // Show an alert if the email is empty
            let alert = UIAlertController(title: "Error", message: "Please enter your email address", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            present(alert, animated: true, completion: nil)
            return
        }
        
        completion?(email)
        dismiss(animated: true, completion: nil)
    }
}
